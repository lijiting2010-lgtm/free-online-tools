#!/bin/bash
# ==========================================
# ETH收款自动监控脚本
# 每5分钟运行一次，检查地址收款并记录
# ==========================================

ETH_ADDRESS="0xC1957c933eaAD66fe44A269dcB0C93C3DFDD38eB"
LOG_FILE="/Users/jg/Desktop/AI生成文件/free-online-tools/payments.json"

# 用Ethplorer API查最近交易
RESULT=$(curl -s "https://api.ethplorer.io/getAddressHistory/${ETH_ADDRESS}?apiKey=freekey&limit=10" 2>/dev/null)

# 检查是否有新交易
if [ -z "$RESULT" ]; then
    echo "[$(date)] Ethplorer查询失败" >> /tmp/eth_monitor.log
    exit 1
fi

# 解析交易
echo "$RESULT" | python3 -c "
import json, sys, time
from datetime import datetime

try:
    data = json.load(sys.stdin)
except:
    print('解析失败')
    sys.exit(1)

address = '$ETH_ADDRESS'.lower()
log_file = '$LOG_FILE'

# 读取已有记录
try:
    with open(log_file) as f:
        records = json.load(f)
except:
    records = {'payments': [], 'last_check': None}

# 获取已有交易哈希列表
known_txs = set(r.get('hash') for r in records['payments'])

new_payments = []
if 'operations' in data:
    for op in data['operations']:
        tx_hash = op.get('hash', '')
        if tx_hash in known_txs:
            continue
        
        # 检查是否是收款
        to_addr = op.get('to', '').lower()
        if to_addr != address:
            continue
        
        value = op.get('value', 0)
        token_info = op.get('tokenInfo', {})
        
        if token_info:
            # 代币转账（USDT等）
            decimals = token_info.get('decimals', 18)
            symbol = token_info.get('symbol', 'TOKEN')
            amount = value / (10 ** decimals)
        else:
            # ETH转账
            amount = value / 1e18
            symbol = 'ETH'
        
        timestamp = op.get('timestamp', int(time.time()))
        date_str = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S')
        
        payment = {
            'hash': tx_hash,
            'from': op.get('from', ''),
            'to': op.get('to', ''),
            'amount': amount,
            'symbol': symbol,
            'timestamp': timestamp,
            'date': date_str,
            'detected_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'status': 'confirmed'
        }
        
        records['payments'].append(payment)
        new_payments.append(payment)
        print(f'✅ 新收款: {amount} {symbol} - {date_str}')

records['last_check'] = datetime.now().isoformat()

with open(log_file, 'w') as f:
    json.dump(records, f, ensure_ascii=False, indent=2)

if new_payments:
    print(f'共发现 {len(new_payments)} 笔新收款！')
    # TODO: 可以在这里添加通知（邮件、微信等）
" 2>&1 | tee -a /tmp/eth_monitor.log
