package com.example.jukebox.test;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller
@ResponseBody
public class TestController {

  @GetMapping("/")
  public String testProcess() {
    System.out.println("Test Controller");
    return "Test Controller";
  }
}
