SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store Procedure: r_cn_hmpickslip                                           */
/* Creation Date: 08-SEP-2015                                                 */
/* Copyright: IDS                                                             */
/* Written by: CSCHONG                                                        */
/*                                                                            */
/* Purpose: For CN LIT datawindow                                             */
/*                                                                            */
/*                                                                            */
/* Called By:  r_cn_hmpickslip                                                */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 1.0                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.     Purposes                                   */
/* 2018.05.04   Fay       1.0      add logic                                  */
/* 2018.10.11   Fay       2.0      add condition(Fay02)                       */
/* 2020-03-16   WLChooi   2.1      WMS-12447 - Add logic based on Codelkup    */
/*                                 setup (WL01)                               */
/******************************************************************************/

CREATE PROC [dbo].[isp_cn_hmpickslip]
@route nvarchar(10),
@loadkey nvarchar(10)
AS

BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @storerkey nvarchar(10),@TotalLines int
   DECLARE @c_Orderkey nvarchar(10),@n_TTLQty INT
   DECLARE @notes nvarchar(4000)
   DECLARE @n_TTLOrderNo INT
   
   SELECT TOP 1 @storerkey      = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE LOADKEY =  @loadkey
   
   --WL01 Start
   DECLARE @c_Short       NVARCHAR(20)
         , @c_Notes2      NVARCHAR(20)
         , @c_Datawindow  NVARCHAR(50) = 'r_cn_cospickslip'

   /*IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'HMLABLE' AND Storerkey = @storerkey and Code2 = @c_Datawindow)
   BEGIN
      SET @n_Found = 1
   END*/
   --WL01 End

   create table #HM_Label1
   (OrderNo             int,
    OrderKey            nvarchar(10),
    LogicalLocation     nvarchar(20),
    SKU                 nvarchar(20),
    Route               nvarchar(20),
    Qty                 int,
    Loc                 nvarchar(10),
    Loadkey             nvarchar(10),
    ExternLineNo        nvarchar(20),
    LineNumber          int,
    TotalLines          int,
    SKUDESCR            nvarchar(90),
    Notes               nvarchar(4000),
    UserDefine03        NVARCHAR(20)  )   --WL01
   
   SELECT ROW_NUMBER() OVER (ORDER BY OrderKey) AS OrderNo,Orderkey as orderkey,LoadKey as loadkey
   INTO #Temp1
   FROM  Orders WITH (NOLOCK)
   WHERE Storerkey = @storerkey and Loadkey = @loadkey AND (Route = @route or @route = 0)
   
   SELECT a.OrderKey as orderkey, b.SKU as sku, c.LogicalLocation as LogicalLocation ,b.Loc as loc , a.Route as [Route], SUM(b.Qty) as qty,
   d.ExternLineNo as ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')) as SKUDESCR ,isnull(b.Notes,'') as Notes,
   ISNULL(a.UserDefine03,'') AS UserDefine03   --WL01
   INTO #TEMP2
   FROM Orders a WITH (NOLOCK)
   JOIN PickDetail b(NOLOCK) on a.OrderKey = b.OrderKey
   JOIN Loc c (NOLOCK) on b.Loc = c.Loc
   JOIN OrderDetail d (NOLOCK) on b.OrderKey = d.OrderKey and b.OrderLineNumber = d.OrderLineNumber
   WHERE a.Storerkey = @storerkey and a.LoadKey = @loadkey
   AND Not exists (select  1 from pickdetail a(nolock) join loc b(nolock) on a.loc = b.loc
   join orders c(nolock) on a.orderkey = c.orderkey
   where c.Storerkey = @storerkey and c.LoadKey = @loadkey and b.locationtype <>'PICK' )
   GROUP BY a.OrderKey, b.SKU, c.LogicalLocation,b.Loc, a.Route,
   d.ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) , RTRIM(ISNULL(d.UserDefine02,'')),isnull(b.Notes,''),
   ISNULL(a.UserDefine03,'') --WL01
   
   
   select  @notes = min(notes )
   from  #TEMP2
   
   while @notes is not null
   begin
   
      insert into #HM_Label1
      (OrderNo,            OrderKey,           LogicalLocation,    SKU,
       Route,              Qty,                Loc,                        Loadkey,
       ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR,
       Notes, UserDefine03 )   --WL01
      select
       t1.OrderNo,         t1.OrderKey,        t2.LogicalLocation,         t2.SKU,
       t2.Route,           t2.Qty,             t2.Loc,                     t1.LoadKey,
       t2.ExternLineNo,    ROW_NUMBER() OVER (ORDER BY t2.LogicalLocation,t2.Loc,t1.OrderKey,t2.SKU),  0,   t2.SKUDESCR ,
       t2.Notes,           t2.UserDefine03   --WL01
      from #TEMP1 AS t1 JOIN #TEMP2 AS t2 ON t1.orderkey = t2.orderkey
      Cross join master.dbo.spt_values B               --Fay02  
      where type='P' and  number<=t2.Qty and number>0  
      And t2.Notes = @notes  
      order by t2.LogicalLocation,t2.Loc,t1.OrderKey,t2.SKU  
      
      select @TotalLines = count(*)
      from #HM_Label1(nolock)
      where Notes = @notes
      
      update #HM_Label1
      set TotalLines = @TotalLines
      where Notes = @notes
      
      
      DECLARE CUR_Orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Orderkey
      FROM #HM_Label1
      where Notes = @notes
      Order by Orderkey
      
      SET @n_TTLOrderNo = 0
      
      OPEN CUR_Orderkey
      FETCH NEXT FROM CUR_Orderkey INTO @c_Orderkey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      
         SET @n_TTLQty = 0
         SET @n_TTLOrderNo = @n_TTLOrderNo+1
      
         SELECT @n_TTLQty = count(*)
         FROM #HM_Label1
         WHERE OrderKey = @c_Orderkey  and  Notes = @notes
      
         UPDATE #HM_Label1
         SET Qty = @n_TTLQty, OrderNo = @n_TTLOrderNo
         WHERE Orderkey=@c_Orderkey and  Notes = @notes
      
      FETCH NEXT FROM CUR_Orderkey INTO @c_Orderkey
      END
      
      CLOSE CUR_Orderkey
      DEALLOCATE  CUR_Orderkey
      
      --update #HM_Label1
      --set Qty = b.Qty
      --from #HM_Label1 a join (select OrderKey, sum(Qty) as Qty from #HM_Label1  group by OrderKey) as b on a.OrderKey = b.OrderKey
      
      select  @notes = min(notes )
      from  #TEMP2
      where notes > @notes
   
   end
   
   --IF @n_Found <> 1
   --BEGIN
   SELECT
   OrderNo,            OrderKey,           LogicalLocation,            substring(SKU,1,7) + ' '+substring(SKU,8,3) + ' ' + substring(SKU,12,2) as SKU,
   Route,              Qty,                Loc,                        Loadkey,
   ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR,
   t.Notes, substring(t.notes,14,3) as BatchNo,
   ISNULL(CL.Short,'') AS Facility, ISNULL(CL.Notes2,'') AS Long
   FROM #HM_Label1 t(nolock)
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'HMLABLE' AND CL.code2 = @c_Datawindow AND CL.Storerkey = @storerkey AND CL.Notes = t.UserDefine03
   ORDER BY t.Notes, t.LineNumber
   /*END
   ELSE
   BEGIN
      SELECT
      OrderNo,            OrderKey,           LogicalLocation,            substring(SKU,1,7) + ' '+substring(SKU,8,3) + ' ' + substring(SKU,12,2) as SKU,
      Route,              Qty,                Loc,                        Loadkey,
      ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR,
      Notes, substring(notes,14,3) as BatchNo
      FROM #HM_Label1(nolock)
      ORDER BY Notes, LineNumber
   END*/
   
END


GO