const { v4: uuidv4 } = require('uuid');
const { createScriptLogger } = require('../utils/logger');
const { getDatabase, getCollection, closeConnection } = require('../utils/mongodb-pool');
const logger = createScriptLogger('create-android-world');

// 默认配置
const DEFAULT_CONFIG = {
  host: 'localhost',
  basePort: 5000,
  mongoUrl: process.env.MONGODB_URI || 'mongodb://cogagent:mongo_tFtnBB@10.50.38.3:37017/cogagent_world?authSource=admin',
};

/**
 * 创建Android环境记录
 * 注意：此函数只创建数据库记录，实际Docker容器由外部系统创建
 * Docker容器启动命令示例：
 * sudo docker run -d \
 *   --name "$CONTAINER_NAME" \
 *   --privileged \
 *   -p $HOST_PORT:5000 \
 *   -p $ADB_PORT:5556 \
 *   -v /home/liwenkai_4cbded1a/android_world:/aw \
 *   -e HTTP_PROXY=http://host.docker.internal:7897 \
 *   -e HTTPS_PROXY=http://host.docker.internal:7897 \
 *   -e NO_PROXY=localhost,127.0.0.1 \
 *   --add-host host.docker.internal:host-gateway \
 *   "$IMAGE"
 * 
 * @param {Object} options 配置选项
 * @param {string} options.host 主机地址
 * @param {number} options.basePort 控制端口 (映射到容器内部5000端口)
 * @param {number} options.adbPort ADB端口 (映射到容器内部5556端口)
 * @param {string} options.containerName Docker容器名称
 * @param {string} options.name 环境名称
 * @param {string} options.description 环境描述
 * @param {string} options.uuid 外部传入的UUID
 * @returns {Promise<string|null>} 创建的world UUID
 */
async function createAndroidWorld(options = {}) {
  const {
    host = DEFAULT_CONFIG.host,
    basePort = DEFAULT_CONFIG.basePort,
    adbPort = null,
    containerName = null,
    name = null,
    description = null,
    uuid: providedUuid = null,
    for_annotation = false,
    status = 'running', // 默认状态为running，可通过参数覆盖
  } = options;

  const uuid = providedUuid || uuidv4().substring(0, 8);
  const worldName = name || `android-${Date.now()}`;

  // 控制端口 (映射到容器内部5000端口)
  const controlPort = basePort;

  // ADB端口 (映射到容器内部5556端口)
  const actualAdbPort = adbPort || (controlPort + 56); // 默认规律：控制端口+56

  // Android环境端口映射
  const allPortsMapping = {
    control: controlPort,    // 主控制端口 -> 容器5000
    adb: actualAdbPort,     // ADB调试端口 -> 容器5556
  };

  // 设置环境配置
  const config = {
    android_port: controlPort,
    adb_port: actualAdbPort,
    container_name: containerName || `android-${uuid}`,
    docker_config: {
      privileged: true,
      volumes: ['/home/liwenkai_4cbded1a/android_world:/aw'],
      environment: {
        HTTP_PROXY: 'http://host.docker.internal:7897',
        HTTPS_PROXY: 'http://host.docker.internal:7897',
        NO_PROXY: 'localhost,127.0.0.1'
      },
      extra_hosts: ['host.docker.internal:host-gateway'],
      port_mapping: {
        '5000': controlPort,  // 容器内5000端口映射到主机控制端口
        '5556': actualAdbPort // 容器内5556端口映射到主机ADB端口
      }
    }
  };

  try {
    // 使用连接池获取集合
    const collection = await getCollection('worlds_android');

    const worldRecord = {
      uuid,
      name: worldName,
      env_type: 'android',
      description: description || '通过脚本创建的Android环境',
      host,
      control_port: controlPort,
      all_ports: allPortsMapping,
      status: status, // 使用传入的状态参数
      is_free: true, // 默认设置为可用
      for_annotation: for_annotation,
      config,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    // 使用 upsert 操作：如果UUID已存在则更新，否则创建新记录
    const result = await collection.replaceOne(
      { uuid }, // 查询条件
      worldRecord, // 替换的文档
      { upsert: true } // 如果不存在则插入
    );

    if (result.upsertedCount > 0) {
      logger.info(`Android环境记录创建成功 (新建)`, {
        uuid,
        name: worldName,
        host,
        control_port: controlPort,
        adb_port: actualAdbPort,
        container_name: config.container_name,
        status: status,
      });
      console.log(`创建成功，UUID: ${uuid}`);
    } else if (result.modifiedCount > 0) {
      logger.info(`Android环境记录更新成功 (状态更新)`, {
        uuid,
        name: worldName,
        host,
        control_port: controlPort,
        adb_port: actualAdbPort,
        container_name: config.container_name,
        status: status,
        operation: 'update'
      });
      console.log(`更新成功，UUID: ${uuid}，状态: ${status}`);
    } else {
      logger.info(`Android环境记录无变化`, {
        uuid,
        status: status,
      });
      console.log(`记录已存在且无变化，UUID: ${uuid}`);
    }

    logger.info(`Android环境记录创建成功`, {
      uuid,
      name: worldName,
      host,
      control_port: controlPort,
      adb_port: actualAdbPort,
      container_name: config.container_name,
    });

    console.log(`创建成功，UUID: ${uuid}`);
    console.log(`环境名称: ${worldName}`);
    console.log(`主机地址: ${host}`);
    console.log(`控制端口: ${controlPort} (映射到容器5000端口)`);
    console.log(`ADB端口: ${actualAdbPort} (映射到容器5556端口)`);
    console.log(`容器名称: ${config.container_name}`);

    return uuid;
  } catch (error) {
    logger.error('创建Android环境记录失败:', { error });
    console.error('创建失败:', error.message);
    return null;
  } finally {
    // 关闭数据库连接
    await closeConnection();
  }
}

// 命令行参数解析
function parseArguments() {
  const args = process.argv.slice(2);
  const options = {};

  for (let i = 0; i < args.length; i += 2) {
    const key = args[i];
    const value = args[i + 1];

    switch (key) {
      case '--host':
        options.host = value;
        break;
      case '--port':
        options.basePort = parseInt(value);
        break;

      case '--adb-port':
        options.adbPort = parseInt(value);
        break;
      case '--container-name':
        options.containerName = value;
        break;
      case '--name':
        options.name = value;
        break;
      case '--description':
        options.description = value;
        break;
      case '--uuid':
        options.uuid = value;
        break;
      case '--for-annotation':
        options.for_annotation = value === 'true';
        break;
      case '--status':
        options.status = value;
        break;
      default:
        // 忽略未知参数
        break;
    }
  }

  return options;
}

// 主函数
async function main() {
  try {
    const options = parseArguments();

    logger.info('开始创建Android环境记录', options);

    const uuid = await createAndroidWorld(options);

    if (uuid) {
      logger.info('Android环境记录创建成功', { uuid });
      process.exit(0);
    } else {
      logger.error('Android环境记录创建失败');
      process.exit(1);
    }
  } catch (error) {
    logger.error('脚本执行失败:', { error });
    console.error('脚本执行失败:', error.message);
    process.exit(1);
  }
}

// 如果直接运行此脚本
if (require.main === module) {
  main();
}

module.exports = { createAndroidWorld };
