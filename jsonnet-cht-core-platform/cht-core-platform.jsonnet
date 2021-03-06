function(
  chtCoreImage='enyachoke/medic-cli:latest',
  couchDbImage='bitnami/couchdb:2',
  containerPort=5988,
  replicas=1,
  name='cht-core-platform',
  servicePort=5988,
  type='ClusterIP',
  pullPolicy='Always',
  buildsServer='https://build-server.lg-apps.com/_couch/builds',
  chtCoreSecrets='couchdb-secrets',
  couchdbSecrets='couchdb-secrets',
  chtCoreVersion='3.6.0',
  couchDbNodeName='couchdb@127.0.0.1',
  couchDbServer='localhost',
  chtCoreServer='localhost',
  couchDbProtocal='http',
  couchDbUser='admin',
  couchDbPort=5984,
  adminUser='admin',
  dataPort=5984,
  adminPort=5986,
  volumeCapacity='5Gi',
  ingressHost=name + '-cht-core.livinggoods.net',
  ingressCouchdbHost=name + '-couchdb.livinggoods.net',
)
  [
    {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: name + '-chtcore',
      },
      spec: {
        ports: [
          {
            port: containerPort,
            targetPort: containerPort,
          },
        ],
        selector: {
          app: name + '-chtcore',
        },
        type: type,
      },
    },
    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: name + '-chtcore',
      },
      spec: {
        replicas: replicas,
        revisionHistoryLimit: 3,
        selector: {
          matchLabels: {
            app: name + '-chtcore',
          },
        },
        template: {
          metadata: {
            labels: {
              app: name + '-chtcore',
            },
          },
          spec: {
            volumes: [
              {
                name: 'horti-data',
                persistentVolumeClaim: {
                  claimName: name + '-chtcore' + '-horti-pvc',
                },
              },
            ],
            containers: [
              {
                image: chtCoreImage,
                name: name + '-chtcore',
                volumeMounts: [
                  {
                    name: 'horti-data',
                    mountPath: '/root',
                  },
                ],
                env: [
                  {
                    name: 'COUCHDB_USER',
                    value: couchDbUser,
                  },
                  {
                    name: 'HORTI_BUILDS_SERVER',
                    value: buildsServer,
                  },
                  {
                    name: 'COUCHDB_SERVER',
                    value: couchDbServer,
                  },
                  {
                    name: 'MEDIC_VERSION',
                    value: chtCoreVersion,
                  },
                  {
                    name: 'COUCH_NODE_NAME',
                    value: couchDbNodeName,
                  },
                  {
                    valueFrom: {
                      secretKeyRef: {
                        name: chtCoreSecrets,
                        key: 'adminPassword',
                      },
                    },
                    name: 'COUCHDB_PASSWORD',
                  },
                ],
                readinessProbe: {
                  httpGet: {
                    path: '/',
                    port: 'http',
                  },
                  initialDelaySeconds: 100,
                  periodSeconds: 20,
                  timeoutSeconds: 20,
                },
                livenessProbe: {
                  httpGet: {
                    path: '/',
                    port: 'http',
                  },
                  initialDelaySeconds: 100,
                  periodSeconds: 20,
                  timeoutSeconds: 20,
                },
                ports: [
                  {
                    name: 'http',
                    containerPort: containerPort,
                    protocol: 'TCP',
                  },
                ],
              },
            ],
          },
        },
      },
    },
    {
      apiVersion: 'v1',
      kind: 'PersistentVolumeClaim',
      metadata: {
        annotations: {
          app: name,
        },
        name: name + '-chtcore' + '-horti-pvc',
      },
      spec: {
        accessModes: [
          'ReadWriteOnce',
        ],
        resources: {
          requests: {
            storage: '1Gi',
          },
        },
      },
    },
    {
      apiVersion: 'extensions/v1beta1',
      kind: 'Ingress',
      metadata: {
        annotations: {
          'ingress.kubernetes.io/proxy-body-size': '500m',
          'kubernetes.io/ingress.class': 'nginx',
          'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
          'nginx.ingress.kubernetes.io/proxy-body-size': '500m',
        },
        labels: {
          app: name + '-chtcore',
        },
        name: name + '-chtcore',
      },
      spec: {
        rules: [
          {
            host: ingressHost,
            http: {
              paths: [
                {
                  backend: {
                    serviceName: name + '-chtcore',
                    servicePort: containerPort,
                  },
                  path: '/',
                },
              ],
            },
          },
        ],
      },
    },
    {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: name + '-couchdb',
      },
      spec: {
        ports: [
          {
            port: dataPort,
            targetPort: dataPort,
            protocol: 'TCP',
            name: 'data',
          },
          {
            port: adminPort,
            targetPort: adminPort,
            protocol: 'TCP',
            name: 'admin',
          },
        ],
        selector: {
          app: name + '-couchdb',
        },
        type: type,
      },
    },
    {
      apiVersion: 'apps/v1',
      kind: 'StatefulSet',
      metadata: {
        name: name + '-couchdb',
      },
      spec: {
        replicas: replicas,
        serviceName: name + '-couchdb',
        revisionHistoryLimit: 3,
        selector: {
          matchLabels: {
            app: name + '-couchdb',
          },
        },
        volumeClaimTemplates: [
          {
            metadata: {
              name: 'couchdb-data',
              labels: {
                app: name + '-couchdb',
              },
            },
            spec: {
              accessModes: [
                'ReadWriteOnce',
              ],
              resources: {
                requests: {
                  storage: volumeCapacity,
                },
              },
            },
          },
        ],
        template: {
          metadata: {
            labels: {
              app: name + '-couchdb',
            },
          },
          spec: {
            initContainers: [
              {
                name: name + '-couchdb' + 'init',
                image: 'alpine:3.6',
                command: ['chown', '-R', '1001:1001', '/bitnami/couchdb'],
                volumeMounts: [
                  {
                    name: 'couchdb-data',
                    mountPath: '/bitnami/couchdb',
                  },
                ],
              },
            ],
            containers: [
              {
                image: couchDbImage,
                imagePullPolicy: pullPolicy,
                name: name + '-couchdb',
                env: [
                  {
                    name: 'COUCHDB_USER',
                    value: adminUser,
                  },

                  {
                    valueFrom: {
                      secretKeyRef: {
                        name: couchdbSecrets,
                        key: 'adminPassword',
                      },
                    },
                    name: 'COUCHDB_PASSWORD',
                  },
                ],
                volumeMounts: [
                  {
                    name: 'couchdb-data',
                    mountPath: '/bitnami/couchdb',
                  },
                ],
                ports: [
                  {
                    name: 'data',
                    containerPort: dataPort,
                  },
                  {
                    name: 'admin',
                    containerPort: dataPort,
                  },
                ],
              },
            ],
          },
        },
      },
    },
    {
      apiVersion: 'extensions/v1beta1',
      kind: 'Ingress',
      metadata: {
        annotations: {
          'ingress.kubernetes.io/proxy-body-size': '500m',
          'kubernetes.io/ingress.class': 'nginx',
          'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
          'nginx.ingress.kubernetes.io/proxy-body-size': '500m',
        },
        labels: {
          app: name + '-couchdb',
        },
        name: name + '-couchdb',
      },
      spec: {
        rules: [
          {
            host: ingressCouchdbHost,
            http: {
              paths: [
                {
                  backend: {
                    serviceName: name + '-couchdb',
                    servicePort: dataPort,
                  },
                  path: '/',
                },
              ],
            },
          },
        ],
      },
    },
    {
      apiVersion: 'batch/v1',
      kind: 'Job',
      metadata: {
        name: name + '-config',
        annotations:{
          'argocd.argoproj.io/hook': 'PostSync'
        },
      },
      spec: {
        template: {
          metadata: {
            name: name + '-config',
          },
          spec: {
            containers: [
              {
                name: name + '-config',
                image: 'registry.livinggoods.net/medic-conf',
                command: ['/conf/run.sh'],
                env: [
                  {
                    name: 'COUCHDB_USER',
                    value: adminUser,
                  },
                  {
                    valueFrom: {
                      secretKeyRef: {
                        name: chtCoreSecrets,
                        key: 'adminPassword',
                      },
                    },
                    name: 'COUCHDB_PASSWORD',
                  },
                  {
                    name: 'COUCHDB_SERVER',
                    value: chtCoreServer,
                  },
                  {
                    name: 'COUCHDB_PORT',
                    value: '5988',
                  },
                ],
              },
            ],
            restartPolicy: 'OnFailure',
          },
        },
      },
    },
  ]
