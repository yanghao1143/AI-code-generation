package nlp

import (
    "testing"
    m "xingzuo/internal/model"
)

// 验证中文短语级关系解析：
// - 一个用户有多个订单 → User (1:N) Order，FK=user_id
// - 用户与收藏是多对多 → User (M:N) Favorite，through=favorite_user（按字典序组合）
// - 每个订单对应一个支付 → Order (1:1) Payment
func TestParseRelationsFromPhrases_Chinese(t *testing.T) {
    text := "一个用户有多个订单。用户与收藏是多对多。每个订单对应一个支付。"
    entities := []m.Entity{
        {Name: "User"}, {Name: "Order"}, {Name: "Favorite"}, {Name: "Payment"},
    }
    rels := parseRelationsFromPhrases(text, entities)

    var oneToManyOK, manyToManyOK, oneToOneOK bool
    for _, r := range rels {
        if r.Type == m.OneToMany && r.From == "User" && r.To == "Order" && r.FKName == "user_id" {
            oneToManyOK = true
        }
        if r.Type == m.ManyToMany {
            // 期望 User<->Favorite，through=favorite_user（按字典序：favorite在前）
            if (r.From == "User" && r.To == "Favorite") || (r.From == "Favorite" && r.To == "User") {
                if r.Through == "favorite_user" {
                    manyToManyOK = true
                }
            }
        }
        if r.Type == m.OneToOne && r.From == "Order" && r.To == "Payment" {
            oneToOneOK = true
        }
    }

    if !oneToManyOK {
        t.Fatalf("缺少 一对多 User->Order (FK=user_id)，实际: %+v", rels)
    }
    if !manyToManyOK {
        t.Fatalf("缺少 多对多 User<->Favorite (through=favorite_user)，实际: %+v", rels)
    }
    if !oneToOneOK {
        t.Fatalf("缺少 一对一 Order->Payment，实际: %+v", rels)
    }
}

// 验证中文字段约束解析：必填/唯一/索引/长度/decimal 精度与外键
func TestParseFieldSpec_ChineseConstraints(t *testing.T) {
    // 1) 必填+唯一+索引+长度
    f1 := parseFieldSpec("手机号(必填, 唯一, 字符串(20), 索引)")
    if f1.Name != "phone" || f1.Type != m.FieldString || f1.Length != 20 || !f1.Unique || !f1.Index || f1.Nullable {
        t.Fatalf("手机号 解析不符合预期: %+v", f1)
    }

    // 2) decimal 精度/小数位
    f2 := parseFieldSpec("总金额(小数(12,2))")
    if f2.Name != "total_amount" || f2.Type != m.FieldDecimal || f2.Precision != 12 || f2.Scale != 2 {
        t.Fatalf("总金额 小数规格解析不符合预期: %+v", f2)
    }

    // 3) 唯一索引
    f3 := parseFieldSpec("邮箱(唯一索引)")
    if f3.Name != "email" || !f3.Unique || !f3.Index {
        t.Fatalf("邮箱 唯一索引解析不符合预期: %+v", f3)
    }

    // 4) 全角括号的长度规格
    f4 := parseFieldSpec("标题（字符串（128））")
    if f4.Name != "title" || f4.Type != m.FieldString || f4.Length != 128 {
        t.Fatalf("标题 全角长度规格解析不符合预期: %+v", f4)
    }

    // 5) 外键：用户ID → bigint、索引、默认携带目标
    f5 := parseFieldSpec("用户ID(外键->用户.id)")
    if f5.Name != "user_id" || f5.Type != m.FieldBigInt || !f5.Index || f5.Default != "fk:用户.id" {
        t.Fatalf("用户ID 外键解析不符合预期: %+v", f5)
    }

    // 6) 默认类型：金额 → decimal
    f6 := parseFieldSpec("金额")
    if f6.Name != "amount" || f6.Type != m.FieldDecimal {
        t.Fatalf("金额 默认类型解析不符合预期: %+v", f6)
    }
}