SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store Procedure: isp_jp_ECOM_PickSlip01B                                   */
/* Creation Date: 09-AUG-2019                                                 */
/* Copyright: IDS                                                             */
/* Written by: Cloud                                                          */
/*                                                                            */
/* Purpose: For JP LIT datawindow and copy from isp_jp_ECOM_PickSlip01 to     */
/*          cater new column  Packinginstruction for DW                       */
/*                                                                            */
/* Called By:  r_jp_ecom_pickslip01B                                          */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 1.1                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.  Purposes                                      */
/* 2019/08/09   LCHuang   1.0   Add Packinginstruction info for DW   (H01)    */
/* 2020/01/06   WLChooi   1.1   WMS-11538 - Add remark (WL01)                 */
/* 2020/03/20   WLChooi   1.2   WMS-12588 - Add ReportCFG to show Orderkey    */
/*                              Barcode (WL02)                                */
/* 2020/04/03   WLChooi   1.3   WMS-12588 - Add ReportCFG to show             */
/*                              Pickdetail.ID (WL03)                          */
/******************************************************************************/

CREATE PROC [dbo].[isp_jp_ECOM_PickSlip01B]
   @specialHandling NVARCHAR(1),
   @loadkey NVARCHAR(10),
   @orderkey NVARCHAR(10)
AS

BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @storerkey NVARCHAR(10), @TotalLines INT
   DECLARE @c_Orderkey NVARCHAR(10), @n_TTLQty INT
   DECLARE @N_CONTINUE INT,@n_err int,   @C_ERRMSG NVARCHAR(250)
   
   IF ISNULL(@loadkey, '') = '' AND ISNULL(@orderkey, '') = ''    --H01
   BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = ' Error: Both Orderkey and Loadkey is empty!'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
   END
   
   SELECT TOP 1 @storerkey =  Storerkey
   FROM  ORDERS (NOLOCK)
   WHERE Loadkey  = CASE WHEN ISNULL(@loadkey, '') = '' THEN  Loadkey  ELSE  @loadkey  END    --H01
   AND   OrderKey = CASE WHEN ISNULL(@orderkey,'') = '' THEN  OrderKey ELSE  @orderkey END
   
   
   CREATE TABLE #HM_Label1
   (OrderNo             INT,
    OrderKey            NVARCHAR(10),
    LogicalLocation     NVARCHAR(20),
    SKU                 NVARCHAR(20),
    Qty                 INT,
    Loc                 NVARCHAR(10),
    Loadkey             NVARCHAR(10),
    ExternLineNo        NVARCHAR(20),
    LineNumber          INT,
    TotalLines          INT,
    SKUDESCR            NVARCHAR(90),
    LWDESCR             NVARCHAR(30),
    Remark              NVARCHAR(250),  --WL01
    ShowOrderkeyBarcode NVARCHAR(10),   --WL02
    ShowPickdetailID    NVARCHAR(10),   --WL03
    ID                  NVARCHAR(18),   --WL03
    SortByLoc           NVARCHAR(10) )  --WL01
   
   SELECT ROW_NUMBER() OVER (ORDER BY OrderKey) AS OrderNo,Orderkey as orderkey,LoadKey as loadkey
   INTO #Temp1
   FROM  Orders WITH (NOLOCK)
   WHERE Storerkey = @storerkey
   and Loadkey =  CASE WHEN ISNULL(@loadkey, '') = '' THEN  Loadkey  ELSE  @loadkey  END     --H01
   and OrderKey = CASE WHEN ISNULL(@orderkey, '') = ''THEN  OrderKey ELSE  @orderkey END
   and SpecialHandling = @specialHandling
   
   SELECT a.OrderKey as orderkey, b.SKU as sku, c.LogicalLocation as LogicalLocation ,b.Loc as loc , SUM(b.Qty) as qty,
          d.ExternLineNo as ExternLineNo,
          S.DESCR as SKUDESCR
        , C.Score
        , ISNULL(D.UserDefine03, '') AS [LWCODE]  --H01
        , Remark = CLK.Remark    --WL01
        , ShowOrderkeyBarcode = ISNULL(CLK2.Short,'N')   --WL02
        , ShowPickdetailID = ISNULL(CLK3.Short,'N')      --WL03
        , b.ID   --WL03
        , SortByLoc = ISNULL(CLK4.Short,'N')             --WL01
   INTO #TEMP2
   FROM Orders a WITH (NOLOCK)
   JOIN PickDetail b (NOLOCK) ON a.OrderKey = b.OrderKey
   JOIN Loc c (NOLOCK) ON b.Loc = c.Loc
   JOIN OrderDetail d (NOLOCK) ON b.OrderKey = d.OrderKey AND b.OrderLineNumber = d.OrderLineNumber
   JOIN SKU S (NOLOCK) ON S.sku = b.SKU AND S.storerkey = b.storerkey
   OUTER APPLY (SELECT ISNULL(MAX(CL.LONG),'') AS Remark FROM CODELKUP CL (NOLOCK) WHERE CL.Storerkey = a.StorerKey 
                                 AND CL.Code = a.[Priority] AND a.BuyerPO LIKE CL.code2
                                 AND CL.Short = 'Y' AND CL.LISTNAME = 'DWPCKLBL') AS CLK              --WL01
   LEFT JOIN CODELKUP CLK2 (NOLOCK) ON CLK2.LISTNAME = 'REPORTCFG' AND CLK2.Code = 'ShowOrderkeyBarcode' 
                                   AND CLK2.Long = 'r_jp_ecom_pickslip01b' AND CLK2.Storerkey = @storerkey  --WL02
   LEFT JOIN CODELKUP CLK3 (NOLOCK) ON CLK3.LISTNAME = 'REPORTCFG' AND CLK3.Code = 'ShowPickdetailID' 
                                   AND CLK3.Long = 'r_jp_ecom_pickslip01b' AND CLK3.Storerkey = @storerkey  --WL03
   LEFT JOIN CODELKUP CLK4 (NOLOCK) ON CLK4.LISTNAME = 'REPORTCFG' AND CLK4.Code = 'SortByLoc' 
                                   AND CLK4.Long = 'r_jp_ecom_pickslip01b' AND CLK4.Storerkey = @storerkey  --WL01
   WHERE a.Storerkey = @storerkey
     and a.Loadkey  = CASE WHEN ISNULL(@loadkey, '') = '' THEN  a.Loadkey  ELSE  @loadkey  END --H01
     and a.OrderKey = CASE WHEN ISNULL(@orderkey,'') = '' THEN  a.OrderKey ELSE  @orderkey END
   GROUP BY a.OrderKey, b.SKU, c.LogicalLocation,b.Loc, a.Route,
            d.ExternLineNo,
            S.DESCR
          , C.Score
          , D.UserDefine03
          , CLK.Remark  --WL01
          , ISNULL(CLK2.Short,'N') --WL02
          , ISNULL(CLK3.Short,'N') --WL03
          , b.ID   --WL03
          , ISNULL(CLK4.Short,'N') --WL01
   
   SELECT
      a.orderkey,a.sku,a.logicallocation,a.loc,[qty]=1,a.externlineno,a.skudescr,a.score
      , CASE WHEN LEN(c.AdjInfo) > 0 THEN LEFT(a.[LWCODE],4) --c.Code + '( '+c.AdjInfo+')'   --WL01
             WHEN LEN(c.Code)    > 0 THEN c.Code
        ELSE ISNULL(a.[LWCODE],'')  END  AS [LWDESCR]
      , a.Remark    --WL01
      , a.ShowOrderkeyBarcode   --WL02
      , a.ShowPickdetailID      --WL03
      , a.ID   --WL03
      , a.SortByLoc   --WL01
   INTO #TEMP3
   FROM #TEMP2 AS A(NOLOCK)
   INNER JOIN [master].dbo.spt_values AS M(NOLOCK) ON a.qty > m.number
   LEFT JOIN SKU (NOLOCK) ON SKU.SKU = a.SKU AND SKU.Storerkey = @storerkey   --WL01
   LEFT JOIN  ( SELECT Code, Short AS [AdjInfo] FROM CODELKUP (nolock)  WHERE Storerkey = @storerkey AND [LISTNAME] = 'DWVAS') AS c --H01
   ON         LEFT(a.[LWCODE],4) = c.[Code]
   WHERE m.[type] = 'p'
   
   INSERT INTO #HM_Label1
         ( OrderNo,           OrderKey,           LogicalLocation,            SKU,
          LWDESCR,            Qty,                Loc,                        Loadkey,--H01
           ExternLineNo,      LineNumber,         TotalLines,                 SKUDESCR,
           Remark,      --WL01
           ShowOrderkeyBarcode,     --WL02
           ShowPickdetailID, ID,    --WL03
           SortByLoc )   --WL01
   SELECT  t1.OrderNo,        t1.OrderKey,        t2.LogicalLocation,         t2.SKU,
           t2.LWDESCR,        t2.Qty,             t2.Loc,                     t1.LoadKey,--H01
           t2.ExternLineNo,
           CASE WHEN t2.ShowPickdetailID = 'Y'                                                          --WL03
                   THEN ROW_NUMBER() OVER (ORDER BY t2.LogicalLocation,t2.Loc)                          --WL03
                WHEN t2.SortByLoc = 'Y'                                                                 --WL01 
                   THEN ROW_NUMBER() OVER (ORDER BY t2.Loc)                                             --WL01 
                ELSE ROW_NUMBER() OVER (ORDER BY t2.Score,t2.LogicalLocation,t2.Loc,t1.OrderKey) END,   --WL03
           0,   t2.SKUDESCR,
           t2.Remark,    --WL01
           t2.ShowOrderkeyBarcode,      --WL02
           t2.ShowPickdetailID, t2.ID,  --WL03
           t2.SortByLoc   --WL01
   FROM #TEMP1 AS t1 JOIN #TEMP3 AS t2 ON t1.orderkey = t2.orderkey
   
   SELECT @TotalLines = COUNT(*)
   FROM #HM_Label1 (NOLOCK)
   
   UPDATE #HM_Label1
   SET TotalLines = @TotalLines
   
   DECLARE CUR_Orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Orderkey
      FROM #HM_Label1
      Order by Orderkey
   
   OPEN CUR_Orderkey
   FETCH NEXT FROM CUR_Orderkey INTO @c_Orderkey
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_TTLQty = 0
   
      SELECT @n_TTLQty = SUM(qty)
      FROM #HM_Label1
      WHERE OrderKey = @c_Orderkey
   
      UPDATE #HM_Label1
      SET Qty = @n_TTLQty
      WHERE Orderkey=@c_Orderkey
   
      FETCH NEXT FROM CUR_Orderkey INTO @c_Orderkey
   END
   CLOSE CUR_Orderkey
   DEALLOCATE  CUR_Orderkey
   
   --WL02 START
   IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'REPORTCFG' AND Code = 'NoJoinPickHeader' 
                                                AND Short = 'Y' AND Long = 'r_jp_ecom_pickslip01b'
                                                AND Storerkey = @storerkey)
   BEGIN
      SELECT
         A.OrderNo,            A.OrderKey,           A.LogicalLocation,
         A.SKU , -- V1.3
         A.LWDESCR ,           A.Qty,                A.Loc,                  A.Loadkey,    --H01
         A.ExternLineNo,       A.LineNumber,         A.TotalLines,                 A.SKUDESCR,
         '',
         A.Remark,  --WL01
         A.ShowOrderkeyBarcode,         --WL02 
         A.ShowPickdetailID, A.ID,      --WL03
         A.SortByLoc   --WL01
      FROM #HM_Label1 AS A(NOLOCK)
      ORDER BY A.LineNumber
   END
   ELSE
   BEGIN
   --WL02 END
      SELECT
         A.OrderNo,            A.OrderKey,           A.LogicalLocation,
         A.SKU , -- V1.3
         A.LWDESCR ,           A.Qty,                A.Loc,                  A.Loadkey,    --H01
         A.ExternLineNo,       A.LineNumber,         A.TotalLines,                 A.SKUDESCR,
         B.pickheaderkey,
         A.Remark,   --WL01
         A.ShowOrderkeyBarcode,         --WL02
         A.ShowPickdetailID, A.ID,      --WL03
         A.SortByLoc   --WL01
      FROM #HM_Label1 AS A(NOLOCK)
      JOIN  PICKHEADER AS B (NOLOCK) ON A.ORDERKEY = B.ORDERKEY
      ORDER BY A.LineNumber
   END --WL02

END

GO