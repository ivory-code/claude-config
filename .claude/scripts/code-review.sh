#!/bin/bash

# Claude Code 자동 코드 리뷰 스크립트
# 안티패턴, 하드코딩된 시크릿, 보안 이슈를 검사합니다

FILE_PATH="$1"

# 파일이 존재하지 않으면 스킵
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# .env 파일은 스킵 (시크릿을 포함하는 것이 정상)
if [[ "$FILE_PATH" =~ \.env(\.|$) ]]; then
    exit 0
fi

# 파일 확장자 추출
EXT="${FILE_PATH##*.}"

# 코드 파일만 검사
if [[ ! "$EXT" =~ ^(js|jsx|ts|tsx|vue|py|java|go|rb|php)$ ]]; then
    exit 0
fi

# 파일 내용 읽기
CONTENT=$(cat "$FILE_PATH")

# 하드코딩된 시크릿 검사 패턴 (API 키, 토큰, 비밀번호)
SECRETS_PATTERNS=(
    "api[_-]?key['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "api[_-]?secret['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "access[_-]?token['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "auth[_-]?token['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "password['\"]?\s*[:=]\s*['\"][^'\"]{3,}"
    "secret['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "private[_-]?key['\"]?\s*[:=]\s*['\"][^'\"]{10,}"
    "Bearer [A-Za-z0-9._~+/-]+"
)

ISSUES=()

# 하드코딩된 시크릿 검사
for pattern in "${SECRETS_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -iE "$pattern" > /dev/null; then
        ISSUES+=("⚠️  보안: 하드코딩된 시크릿이 감지되었습니다 (패턴: $pattern)")
    fi
done

# JS/TS/Vue 안티패턴 검사
if [[ "$EXT" =~ ^(js|jsx|ts|tsx|vue)$ ]]; then
    # 프로덕션 코드에서 console.log 사용 (테스트 파일 제외)
    if [[ ! "$FILE_PATH" =~ test|spec ]] && echo "$CONTENT" | grep -E "console\.(log|debug|info)" > /dev/null; then
        ISSUES+=("💡 안티패턴: 테스트 파일이 아닌 곳에서 console.log가 발견되었습니다")
    fi

    # 위험한 eval 사용
    if echo "$CONTENT" | grep -E "\beval\s*\(" > /dev/null; then
        ISSUES+=("⚠️  보안: eval() 사용이 감지되었습니다 - 보안 위험 가능성")
    fi

    # TODO/FIXME 코멘트
    if echo "$CONTENT" | grep -iE "\/\/.*TODO|\/\/.*FIXME|\/\*.*TODO|\/\*.*FIXME" > /dev/null; then
        ISSUES+=("📝 참고: TODO/FIXME 코멘트가 발견되었습니다")
    fi
fi

# 결과 출력
if [ ${#ISSUES[@]} -gt 0 ]; then
    echo ""
    echo "🔍 코드 리뷰 결과: $FILE_PATH"
    echo "================================================"
    for issue in "${ISSUES[@]}"; do
        echo "$issue"
    done
    echo "================================================"
    echo ""
fi

exit 0
