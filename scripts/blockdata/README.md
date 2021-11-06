#USAGE:
* Get only exchange rate from specified block range
<pre>
node XchangeRate_by_blocks.js block --f &lt;start block&gt; --t &lt;end block&gt;
</pre>

* Get details of only "LoanContractCreatedEvent" from specified block range
<pre>
node XchangeRate_by_blocks.js block --f &lt;start block&gt; --t &lt;end block&gt; --d
</pre>

* Get all events raw data from specified block range
<pre>
node XchangeRate_by_blocks.js block --f &lt;start block&gt; --t &lt;end block&gt; --a
</pre>

* Get all events refined data from specified block range
<pre>
node XchangeRate_by_blocks.js block --f &lt;start block&gt; --t &lt;end block&gt; --a --d
</pre>

#HELP:
<pre>
node XchangeRate_by_blocks.js --h
</pre>
