SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Stored Procedure: nsp_NIVEA_CartonLabel_FullCarton                   */
/* Creation Date: 2023/07/27                                            */                                             
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  ver  Purposes                                   */
/* 27-07-2023   ZiWei   1.0  Copy From CNLOCAL                          */
/************************************************************************/
  

--var v_externorderkey  
  
--v_externorderkey = ActiveDocument.Sections["CartonLabel_EIS"].Shapes["text_externorderkey"].Text  
  
--ActiveDocument.Sections["Query_CartonLabel(Full Carton)"].SetStoredProcParam(v_externorderkey,1)  
--ActiveDocument.Sections["Query_CartonLabel(Full Carton)"].ProcessStoredProc();  
--ActiveDocument.Sections["CartonLabel_FullCarton"].Activate();  
  
  
--select loadkey,C_Address2,* from cnwms..orders (nolock)where storerkey='NIVEA02'and loadkey='0002023924'  
  
  
  
/* NIVEA Carton Label    
 wwang    
 2010-04-16    
*/    
--nsp_NIVEA_CartonLabel_FullCarton '2', '0002023924'    
--nsp_NIVEA_CartonLabel_FullCarton '1', '3003476890-7'    
--nsp_NIVEA_CartonLabel_FullCarton '1', '3003476890-8'  

CREATE   PROCEDURE [BI].[nsp_NIVEA_CartonLabel_FullCarton]    
@type int ,  
@Externkey NVARchar(30)   
  
as    
  
if @type = '1'--Externorderkey  
begin    
   declare @CartonNo  int,    
           @i         int,    
           @LooseCarton int    
    
   Create table #CartonLabel(    
                iNo           int ,    
                TotalNo       int,    
                Consigneekey  Nvarchar(30),    
                C_Company     nvarchar(45),    
                C_Address1    nvarchar(45),    
                C_Address2    nvarchar(45),    
                C_Address3    nvarchar(45),    
                C_Address4    nvarchar(45),    
                C_City        nvarchar(45),    
                Externorderkey NVARchar(30),  
    Salesman      NVARchar(30))    
    
   Create table #Count(    
                iNo   int )    
    
    
   select @CartonNo=Sum(case when t3.casecnt>0 then (t1.Qty)/cast(t3.casecnt as int) else 1 end )   
   from (select Orderkey, OrderLinenumber, SKU, sum(Qty) as Qty from CNWMS..V_PickDetail as A(nolock)   
   inner join BI.V_Loc as B(nolock) on A.Loc=B.Loc where B.LocationType<>'PICK' group by Orderkey,OrderLinenumber,SKU) as t1   
   inner join BI.V_Orderdetail as t2(nolock) on t1.Orderkey=t2.Orderkey and t1.Orderlinenumber=t2.OrderLinenumber and t1.SKU=t2.SKU    
      
  inner join BI.V_Pack as t3(nolock) on t2.Packkey=t3.Packkey                                                             
   where (t2.storerkey='NIVEACN' or t2.storerkey='HNCN' or t2.storerkey='NIVEA02' or t2.storerkey='18342' or t2.storerkey='18399' OR t2.storerkey='SUMEI') and t2.ExternOrderkey=@Externkey   
  
    
   set @CartonNo=isnull(@CartonNo,0)    
    
   set @i=1    
    
    
   if @CartonNo>0    
   begin    
     set rowcount @CartonNo    
     insert into #Count(iNo) select number from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0      
   end    
    
  if @CartonNo>2047     
   begin    
     set @LooseCarton=@CartonNo-2047    
     set rowcount @LooseCarton    
     insert into #Count(iNo) select number+2047 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
    
  if @CartonNo>4094    
   begin    
     set @LooseCarton=@CartonNo-4094    
     set rowcount @LooseCarton    
     insert into #Count(iNo) select number+4094 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
     
  if @CartonNo>6141    
   begin    
     set @LooseCarton=@CartonNo-6141    
     set rowcount @LooseCarton    
     insert into #Count(iNo) select number+6141 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
    
     if @CartonNo>8188    
   begin    
     set @LooseCarton=@CartonNo-8188    
     set rowcount @LooseCarton    
     insert into #Count(iNo) select number+8188 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
    
   if @CartonNo>10235  
   begin    
     set @LooseCarton=@CartonNo-10235   
     set rowcount @LooseCarton    
     insert into #Count(iNo) select number+10235 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
     
    if @CartonNo>12282  
   begin    
     set @LooseCarton=@CartonNo-12282  
     set rowcount @LooseCarton    
     insert into #Count(iNo) select number+12282 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
     
    if @CartonNo>14329  
   begin    
     set @LooseCarton=@CartonNo-14329  
     set rowcount @LooseCarton    
     insert into #Count(iNo) select number+14329 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
     
    if @CartonNo>16376  
   begin    
     set @LooseCarton=@CartonNo-16376  
     set rowcount @LooseCarton    
     insert into #Count(iNo) select number+16376 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
     
     
       insert into #CartonLabel(iNo,TotalNo,Consigneekey,C_Company,C_Address1,C_Address2,C_Address3,C_Address4,C_City,Externorderkey,Salesman)    
       select t2.iNo,@CartonNo,Consigneekey, C_Company,  isnull(C_Address1,'') ,  
              isnull(C_Address2,'') ,isnull(C_Address3,''),     
              isnull(C_Address4,''),C_City,Externorderkey,Salesman  
       from BI.V_Orders(nolock) inner join #Count as t2(nolock) on 1=1    
       where (storerkey='NIVEACN' or storerkey='HNCN' or storerkey='NIVEA02' or storerkey='18342' or storerkey='18399' OR storerkey='SUMEI') and ExternOrderkey=@Externkey    
    
    
    
     
  select * from #CartonLabel(nolock)    
    
    
    
end    
    
    
else if @Type='2' -- Loadkey  
begin    
   declare @CartonNo2  int,    
           @i2         int,    
           @LooseCarton2 int    
    
   Create table #CartonLabel2(    
                iNo           int ,    
                TotalNo       int,    
                Consigneekey  Nvarchar(30),    
                C_Company     nvarchar(45),    
                C_Address1    nvarchar(45),    
                C_Address2    nvarchar(45),    
                C_Address3    nvarchar(45),    
                C_Address4    nvarchar(45),    
                C_City        nvarchar(45),    
    Salesman      NVARchar(30),  
    LoadKey NVARchar(30),  
    Externorderkey NVARchar(30) )    
    
   Create table #Count2(    
                iNo   int )    
    
    
   select distinct @CartonNo2=Sum(case when t3.casecnt>0 then (t1.Qty)/cast(t3.casecnt as int) else 1 end )   
   from (select distinct Orderkey, OrderLinenumber, SKU, sum(Qty) as Qty from CNWMS..V_PickDetail as A(nolock)   
   inner join BI.V_Loc as B(nolock) on A.Loc=B.Loc where B.LocationType<>'PICK' group by Orderkey,OrderLinenumber,SKU) as t1   
   inner join BI.V_Orderdetail as t2(nolock) on t1.Orderkey=t2.Orderkey and t1.Orderlinenumber=t2.OrderLinenumber and t1.SKU=t2.SKU    
   inner join BI.V_Pack as t3(nolock) on t2.Packkey=t3.Packkey  
   inner join BI.V_OrderS as t4(nolock) on t4.Orderkey=t2.Orderkey and   t4.storerkey=t2.storerkey                                                                   
   where (t2.storerkey='NIVEACN' or t2.storerkey='HNCN' or t2.storerkey='NIVEA02' or t2.storerkey='18342' or t2.storerkey='18399' OR t2.storerkey='SUMEI') and t4.Loadkey=@Externkey   
  
    
   set @CartonNo2=isnull(@CartonNo2,0)    
    
   set @i2=1    
    
    
   if @CartonNo2>0    
   begin    
     set rowcount @CartonNo2    
     insert into #Count2(iNo) select number from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0      
   end    
    
  if @CartonNo2>2047     
   begin    
     set @LooseCarton2=@CartonNo2-2047    
     set rowcount @LooseCarton2    
     insert into #Count2(iNo) select number+2047 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
    
  if @CartonNo2>4094    
   begin    
     set @LooseCarton2=@CartonNo2-4094    
     set rowcount @LooseCarton2    
     insert into #Count2(iNo) select number+4094 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
     
  if @CartonNo2>6141    
   begin    
     set @LooseCarton2=@CartonNo2-6141    
     set rowcount @LooseCarton2    
     insert into #Count2(iNo) select number+6141 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
    
     if @CartonNo2>8188    
   begin    
     set @LooseCarton2=@CartonNo2-8188    
     set rowcount @LooseCarton2    
     insert into #Count2(iNo) select number+8188 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
    
   if @CartonNo2>10235  
   begin    
     set @LooseCarton2=@CartonNo2-10235   
     set rowcount @LooseCarton2    
     insert into #Count2(iNo) select number+10235 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
     
    if @CartonNo2>12282  
   begin    
     set @LooseCarton2=@CartonNo2-12282  
     set rowcount @LooseCarton2    
     insert into #Count2(iNo) select number+12282 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
     
    if @CartonNo2>14329  
   begin    
     set @LooseCarton2=@CartonNo2-14329  
     set rowcount @LooseCarton2    
     insert into #Count2(iNo) select number+14329 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
     
    if @CartonNo2>16376  
   begin    
     set @LooseCarton2=@CartonNo2-16376  
     set rowcount @LooseCarton2    
     insert into #Count2(iNo) select number+16376 from master..spt_values b where b.type='p' and b.number<>0    
     set rowcount 0     
   end    
     
     
       insert into #CartonLabel2(iNo,TotalNo,Consigneekey,C_Company,C_Address1,C_Address2,C_Address3,C_Address4,C_City,Salesman,LoadKey,Externorderkey)    
       select   t2.iNo,@CartonNo2,Consigneekey, C_Company,    
     isnull(C_Address1,'') ,  
              isnull(C_Address2,'') ,isnull(C_Address3,''),     
              isnull(C_Address4,'')  
            ,C_City,Salesman,LoadKey,Externorderkey  
       from BI.V_Orders(nolock) inner join #Count2 as t2(nolock) on 1=1    
       where (storerkey='NIVEACN' or storerkey='HNCN' or storerkey='NIVEA02' or storerkey='18342' or storerkey='18399' OR storerkey='SUMEI') and Loadkey=@Externkey    
    
  
    
     
  select * from #CartonLabel2(nolock)    
    
    
    
end    

GO