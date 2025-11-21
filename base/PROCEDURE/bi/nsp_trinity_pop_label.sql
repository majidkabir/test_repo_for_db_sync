SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Title: nsp_Trinity_POP_Label                                          */

/* Date         Author   Ver  Purposes                                   */
/* 20-Mar-2023  Ziwei    1.0  Created                                    */
/*************************************************************************/

CREATE   PROC [BI].[nsp_Trinity_POP_Label] --NAME OF SP
         @pickslipno NVARCHAR(20) = ''
         ,@ctntotal int
         ,@ctnreprint int = 0
         
           
AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= CONCAT('{ "@pickslipno":"',@pickslipno,'"'
                                    , ', "@ctntotal":"',@ctntotal,'"'
                                    , ', "@ctnreprint":"',@ctnreprint,'"''}')

   EXEC BI.dspExecInit @ClientId = '18329'
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only

declare @storerkey NVARchar(20),@externorderkey NVARchar(20),@shipto NVARchar(20)
declare @ctn int,@curs cursor

select @storerkey = '18329'
,@ctnreprint = isnull(@ctnreprint,0)
, @externorderkey = isnull(a.externorderkey,'')
, @shipto = isnull(a.consigneekey,'')
from BI.V_orders as a(nolock)
join BI.V_pickheader as b(nolock) on a.orderkey = b.orderkey
where b.pickheaderkey = @pickslipno

IF OBJECT_ID('tempdb..#Count') IS NULL
BEGIN
   Create table #Count
   (iNo   int )
END

IF OBJECT_ID('tempdb..#POP') IS NULL
BEGIN
create table #POP
   (externorderkey nchar(20),
    consigneekey   nchar(20),
    company        nchar(45),
    address        nchar(180),
    ctn1           int,
    ctn2           int)
END

IF @ctntotal IS NOT NULL
BEGIN
   set rowcount @ctntotal
   insert into #Count(iNo) select number from master..spt_values b where b.type='p' and b.number<>0      
   set rowcount 0
END

if @ctnreprint > 0
begin
  if @shipto = '' 
     insert into #POP
     (externorderkey,     consigneekey,          company,           address,
      ctn1,               ctn2)
      select 
      a.externorderkey,   a.consigneekey,       isnull(b.Company,''),  
      ltrim(rtrim(isnull(b.Address1,''))) +   ltrim(rtrim(isnull(b.Address2,''))) +
      ltrim(rtrim(isnull(b.Address3,''))) +   ltrim(rtrim(isnull(b.Address4,''))),
      @ctnreprint, @ctntotal   
      from BI.V_Orders a(nolock) join BI.V_Storer b(nolock) on a.Consigneekey = b.Storerkey
      where a.Storerkey = @storerkey and a.ExternOrderKey = @externorderkey
  else 
     insert into #POP
     (externorderkey,     consigneekey,          company,           address,
      ctn1,               ctn2)
      select 
      @externorderkey,    Storerkey,            isnull(Company,''),  
      ltrim(rtrim(isnull(Address1,''))) +   ltrim(rtrim(isnull(Address2,''))) +
      ltrim(rtrim(isnull(Address3,''))) +   ltrim(rtrim(isnull(Address4,''))),
      @ctnreprint, @ctntotal
      from BI.V_Storer(nolock)
      where Storerkey = @shipto 
end
else
begin
 /*
   select @ctn = 1
   
   while @ctn <= @ctntotal
   begin
   insert into #POP
  (externorderkey,     consigneekey,          company,           address,
   ctn1,               ctn2)
  select 
   a.externorderkey,   a.consigneekey,         isnull(b.Company,''),  
   ltrim(rtrim(isnull(b.Address1,''))) +   ltrim(rtrim(isnull(b.Address2,''))) +
   ltrim(rtrim(isnull(b.Address3,''))) +   ltrim(rtrim(isnull(b.Address4,''))),
   @ctn, @ctntotal  
   from CNWMS..Orders a(nolock) join CNWMS..Storer b(nolock) on a.Consigneekey = b.Storerkey
   where a.Storerkey = @storerkey and a.ExternOrderKey = @externorderkey
    
   select @ctn = @ctn + 1
   end */
   
   set @curs=cursor Scroll for 
   select iNo from #Count order by iNo
   open @curs      
   fetch next from @curs into @ctn   
   while @@FETCH_STATUS=0  
   begin
     if @shipto = ''
       insert into #POP
         (externorderkey,     consigneekey,          company,           address,
          ctn1,               ctn2)
        select 
          a.externorderkey,   a.consigneekey,         isnull(b.Company,''),  
          ltrim(rtrim(isnull(b.Address1,''))) +   ltrim(rtrim(isnull(b.Address2,''))) +
          ltrim(rtrim(isnull(b.Address3,''))) +   ltrim(rtrim(isnull(b.Address4,''))),
          @ctn, @ctntotal  
       from BI.V_Orders a(nolock) join BI.V_Storer b(nolock) on a.Consigneekey = b.Storerkey
       where a.Storerkey = @storerkey and a.ExternOrderKey = @externorderkey
    else
       insert into #POP
         (externorderkey,     consigneekey,          company,           address,
          ctn1,               ctn2)
        select 
          @externorderkey,   Storerkey,         isnull(Company,''),  
          ltrim(rtrim(isnull(Address1,''))) +   ltrim(rtrim(isnull(Address2,''))) +
          ltrim(rtrim(isnull(Address3,''))) +   ltrim(rtrim(isnull(Address4,''))),
          @ctn, @ctntotal  
        from BI.V_Storer(nolock)
        where Storerkey = @shipto
        
   fetch next from @curs into @ctn  
   end
   close @curs
end

select externorderkey,     substring(consigneekey,3,len(consigneekey) - 2) as consigneekey,  company,   
       address,  ctn1,               ctn2
from #POP

	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/

SET @stmt = CONCAT(@stmt , '
');


/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO