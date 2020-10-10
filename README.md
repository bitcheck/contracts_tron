#### 对于V1（零知识证明版），编译与部署

1- 需要安装 
```
yarn add circomlib
```

2- 与以太坊上版本不同，需要将`./node_modules/circomlib/src/mimcsponge_gencontract.js`抽取出来，放到`./lib/`下，并且把`web3-utils`改为`tronweb`，并实例化一个`tronWeb`。
另外，将`Web3Utils.keccak256`改为`tronWeb.sha3`。

3- 将以太坊版的`./compileHasher.js`复制到本项目根目录，将引入以上文件的代码改为：
```
const genContract = require('./lib/mimcsponge_gencontract.js')
```

新建`./build`目录，然后运行
```
node ./compileHasher.js
```

在`build`目录下，出现`Hasher.json`，备用

4- 运行`tronbox compile`，编译合约，然后将以上生成的`Hasher.json`替换掉`./build/contracts/`目录下的`Hasher.json`。

5- 运行`tronbox migrate --network 网络`，部署合约

部署前，需要配置`.env`文件。
并且确保`ENERGE`和`BANDWIDTH`足够，如果不够，运行`./test/test.js`脚本中的`freezeBalance`相关指令。

#### V2不需要以上步骤实现零知识证明，直接
```
tronbox migrate --network shasta
tronbox migrate --network mainnet
```

或者启动`Docker`的`quickstart`节点