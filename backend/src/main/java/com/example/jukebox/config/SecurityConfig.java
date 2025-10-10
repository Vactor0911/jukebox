package com.example.jukebox.config;

import lombok.AllArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
@AllArgsConstructor
public class SecurityConfig {
  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    // csrf disable
    http.csrf((auth) -> auth.disable());

    // Form 로그인 방식 disable
    http.formLogin((auth) -> auth.disable());

    // HTTP basic 인증 방식 disable
    http.httpBasic((auth) -> auth.disable());

    // 경로별 인가 작업
    http.authorizeHttpRequests((auth) -> auth
        .requestMatchers("/").permitAll() // 모든 권한 허용
        .anyRequest().authenticated()); // 로그인된 사용자만 접근 허용

    return http.build();
  }
}
