package replytemplates

import (
    "fmt"
    "regexp"
)

// JSON-like schema structures (simplified) for variable validation.
type VarProperty struct {
    Type string `json:"type"`
}

type VarSchema struct {
    Properties map[string]VarProperty `json:"properties"`
    Required   []string               `json:"required"`
}

// ValidateVars checks variables against a simplified schema (type + required).
// Supported types: string, number, boolean.
func ValidateVars(schema VarSchema, vars map[string]interface{}) (bool, []string) {
    issues := make([]string, 0)
    // required checks
    req := make(map[string]struct{}, len(schema.Required))
    for _, k := range schema.Required {
        req[k] = struct{}{}
    }
    for k := range req {
        if _, ok := vars[k]; !ok {
            issues = append(issues, fmt.Sprintf("缺少必填变量: %s", k))
        }
    }
    // type checks
    for k, v := range vars {
        prop, ok := schema.Properties[k]
        if !ok {
            // allow extra variables but warn
            issues = append(issues, fmt.Sprintf("未在Schema声明的变量: %s", k))
            continue
        }
        switch prop.Type {
        case "string":
            if _, ok := v.(string); !ok {
                issues = append(issues, fmt.Sprintf("变量类型不匹配: %s 期望 string", k))
            }
        case "number":
            switch v.(type) {
            case float64, float32, int, int64, int32:
                // ok
            default:
                issues = append(issues, fmt.Sprintf("变量类型不匹配: %s 期望 number", k))
            }
        case "boolean":
            if _, ok := v.(bool); !ok {
                issues = append(issues, fmt.Sprintf("变量类型不匹配: %s 期望 boolean", k))
            }
        default:
            issues = append(issues, fmt.Sprintf("不支持的类型: %s=%s", k, prop.Type))
        }
    }
    return len(issues) == 0, issues
}

var tplVarRegexp = regexp.MustCompile(`\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}`)

// RenderPreview replaces {{var}} placeholders in content using provided variables.
// Non-provided variables remain as-is to surface missing values.
func RenderPreview(content string, vars map[string]interface{}) string {
    return tplVarRegexp.ReplaceAllStringFunc(content, func(m string) string {
        sub := tplVarRegexp.FindStringSubmatch(m)
        if len(sub) != 2 {
            return m
        }
        key := sub[1]
        if v, ok := vars[key]; ok {
            switch vv := v.(type) {
            case string:
                return vv
            case bool:
                if vv {
                    return "true"
                }
                return "false"
            case int, int32, int64:
                return fmt.Sprintf("%d", vv)
            case float32, float64:
                return fmt.Sprintf("%v", vv)
            default:
                return fmt.Sprintf("%v", vv)
            }
        }
        return m
    })
}