# setup_autodl_zsh

AutoDL 一键初始化脚本：配置 `zsh/oh-my-zsh`、缓存与镜像加速、`conda` 默认环境等。

## 文件

- `setup_autodl_zsh.sh`: 主脚本

## 用法

```bash
bash setup_autodl_zsh.sh
```

脚本默认会：

- 把常见缓存与环境目录重定向到 `/root/autodl-tmp`
- 配置 `pip/uv/conda` 镜像
- 确保存在 `py313`（`python=3.13`）并在新终端自动激活
- 尝试将默认 shell 设为 `zsh`
- 新终端默认进入 `/root/autodl-tmp`

## 可选环境变量

```bash
AUTODL_TMP_ROOT=/root/autodl-tmp \
PYPI_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple \
CONDA_MIRROR_ROOT=https://mirrors.tuna.tsinghua.edu.cn/anaconda \
DEFAULT_CONDA_ENV=py313 \
DEFAULT_CONDA_PYTHON=3.13 \
bash setup_autodl_zsh.sh
```
