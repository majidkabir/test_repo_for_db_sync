SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Store Procedure: isp_GetPickSlipOrders99_rdt                          */
/* Creation Date: 26/08/2019                                             */
/* Copyright: LFL                                                        */
/* Written by: WLCHOOI                                                   */
/*                                                                       */
/* Purpose: WMS-10322 [TW] Exceed Piece Picking Report                   */
/*                                                                       */
/* Called By: r_dw_print_pickorder99_rdt                                 */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver.  Purposes                                   */
/*************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders99_rdt] (
            @c_orderkey1  NVARCHAR(10) = '',
            @c_orderkey2  NVARCHAR(10) = '',
            @c_orderkey3  NVARCHAR(10) = '',
            @c_orderkey4  NVARCHAR(10) = '',
            @c_orderkey5  NVARCHAR(10) = '',
            @c_orderkey6  NVARCHAR(10) = '',
            @c_orderkey7  NVARCHAR(10) = '',
            @c_orderkey8  NVARCHAR(10) = '',
            @c_orderkey9  NVARCHAR(10) = '',
            @c_orderkey10 NVARCHAR(10) = '',
            @c_UserID     NVARCHAR(128) = '',
            @c_otherparms NVARCHAR(1)  = 'N',
            @c_LocAisle   NVARCHAR(10) = '',
            @c_Loc        NVARCHAR(10) = '',
            @c_SKU        NVARCHAR(20) = '',
            @c_Descr      NVARCHAR(60) = '',
            @c_Size       NVARCHAR(10) = '' )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @n_StartTCnt       INT
         , @b_success         INT
         , @n_err             INT
         , @c_errmsg          NVARCHAR(255)
         , @n_GetRowID        INT
         , @c_GetOrderkey     NVARCHAR(10)
         , @c_FoundOrderkey   NVARCHAR(10)
         , @n_FoundQty        INT

   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT
   SET @b_success       = 1
   SET @n_err           = 0
   SET @c_errmsg        = ''

   SET @c_orderkey1  = CASE WHEN ISNULL(@c_orderkey1 ,'') = '' THEN '' ELSE @c_orderkey1  END
   SET @c_orderkey2  = CASE WHEN ISNULL(@c_orderkey2 ,'') = '' THEN '' ELSE @c_orderkey2  END
   SET @c_orderkey3  = CASE WHEN ISNULL(@c_orderkey3 ,'') = '' THEN '' ELSE @c_orderkey3  END
   SET @c_orderkey4  = CASE WHEN ISNULL(@c_orderkey4 ,'') = '' THEN '' ELSE @c_orderkey4  END
   SET @c_orderkey5  = CASE WHEN ISNULL(@c_orderkey5 ,'') = '' THEN '' ELSE @c_orderkey5  END
   SET @c_orderkey6  = CASE WHEN ISNULL(@c_orderkey6 ,'') = '' THEN '' ELSE @c_orderkey6  END
   SET @c_orderkey7  = CASE WHEN ISNULL(@c_orderkey7 ,'') = '' THEN '' ELSE @c_orderkey7  END
   SET @c_orderkey8  = CASE WHEN ISNULL(@c_orderkey8 ,'') = '' THEN '' ELSE @c_orderkey8  END
   SET @c_orderkey9  = CASE WHEN ISNULL(@c_orderkey9 ,'') = '' THEN '' ELSE @c_orderkey9  END
   SET @c_orderkey10 = CASE WHEN ISNULL(@c_orderkey10,'') = '' THEN '' ELSE @c_orderkey10 END
   SET @c_UserID     = CASE WHEN ISNULL(@c_UserID,'') = '' THEN '' ELSE @c_UserID END
   
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #Temp_Header96
   ( RowID        INT NOT NULL IDENTITY(1,1),
     Orderkey     NVARCHAR(10),
     Pickslipno   NVARCHAR(10),
     [Priority]   NVARCHAR(10)   )

   CREATE TABLE #Temp_Detail96
   ( Orderkey     NVARCHAR(10),
     LocAisle     NVARCHAR(10),
     Loc          NVARCHAR(10),
     SKU          NVARCHAR(20),
     Descr        NVARCHAR(60),
     Size         NVARCHAR(10),
     OtherSKU     NVARCHAR(50),
     Qty          INT )

   CREATE TABLE #Temp_Orderkey96
   ( RowID         INT NOT NULL IDENTITY(1,1),
     Orderkey      NVARCHAR(10), 
     FoundOrderkey NVARCHAR(10),
     FoundQty      INT )
  
   INSERT INTO #Temp_Header96 (Orderkey, Pickslipno, [Priority])
   SELECT OH.Orderkey, PH.Pickheaderkey, ISNULL(TD.[Priority],'')
   FROM ORDERS OH (NOLOCK) 
   JOIN Pickheader PH (NOLOCK) ON OH.Orderkey = PH.Orderkey
   OUTER APPLY (SELECT TOP 1 [Priority] FROM TASKDETAIL (NOLOCK) WHERE OH.Orderkey = TASKDETAIL.Orderkey) AS TD
   WHERE OH.ORDERKEY IN (@c_orderkey1, @c_orderkey2, @c_orderkey3, @c_orderkey4, @c_orderkey5,
                         @c_orderkey6, @c_orderkey7, @c_orderkey8, @c_orderkey9, @c_orderkey10 )
   ORDER BY OH.Orderkey
     
   INSERT INTO #Temp_Orderkey96
   SELECT Orderkey,'' , 0
   FROM #Temp_Header96
   ORDER BY RowID

   INSERT INTO #Temp_Detail96 (Orderkey, LocAisle, Loc, SKU, Descr, Size, OtherSKU, Qty)
   SELECT PD.Orderkey
        , Loc.LocAisle
        , Loc.Loc
        , PD.Sku
        , SKU.Descr
        , SKU.Size
        , OtherSKU = CASE WHEN ISNULL(CL.Short,'') = 1 THEN SKU.ManufacturerSKU
                          WHEN ISNULL(CL.Short,'') = 2 THEN SKU.RetailSKU
                          WHEN ISNULL(CL.Short,'') = 3 THEN SKU.AltSKU
                          ELSE '' END
        , SUM(PD.Qty)
   FROM PICKDETAIL PD (NOLOCK)
   JOIN LOC (NOLOCK) ON LOC.LOC = PD.LOC
   JOIN SKU (NOLOCK) ON PD.STORERKEY = SKU.STORERKEY AND PD.SKU = SKU.SKU
   JOIN ORDERS ORD (NOLOCK) ON ORD.Orderkey = PD.Orderkey
   LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'REPORTCFG' AND CL.CODE = 'ShowSKU' AND CL.Long = 'r_dw_print_pickorder99_rdt' AND
                                     CL.Storerkey = ORD.Storerkey
   WHERE PD.ORDERKEY IN (@c_orderkey1, @c_orderkey2, @c_orderkey3, @c_orderkey4, @c_orderkey5,
                         @c_orderkey6, @c_orderkey7, @c_orderkey8, @c_orderkey9, @c_orderkey10 )
   GROUP BY PD.Orderkey
          , Loc.LocAisle
          , Loc.Loc
          , PD.Sku
          , SKU.Descr
          , SKU.Size
          , CASE WHEN ISNULL(CL.Short,'') = 1 THEN SKU.ManufacturerSKU
                 WHEN ISNULL(CL.Short,'') = 2 THEN SKU.RetailSKU
                 WHEN ISNULL(CL.Short,'') = 3 THEN SKU.AltSKU
                 ELSE '' END

   IF @c_otherparms = 'N'
   BEGIN
      SELECT ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 1),'') AS Orderkey1
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 1),'') AS Pickslipno1
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 2),'') AS Orderkey2
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 2),'') AS Pickslipno2
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 3),'') AS Orderkey3
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 3),'') AS Pickslipno3
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 4),'') AS Orderkey4
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 4),'') AS Pickslipno4
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 5),'') AS Orderkey5
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 5),'') AS Pickslipno5
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 6),'') AS Orderkey6
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 6),'') AS Pickslipno6
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 7),'') AS Orderkey7
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 7),'') AS Pickslipno7
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 8),'') AS Orderkey8
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 8),'') AS Pickslipno8
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 9),'') AS Orderkey9
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 9),'') AS Pickslipno9
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 10),'') AS Orderkey10
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 10),'') AS Pickslipno10
        , ISNULL((SELECT [Priority] FROM #Temp_Header96 WHERE RowID = 1),'') AS Priority1
        , ISNULL((SELECT [Priority] FROM #Temp_Header96 WHERE RowID = 2),'') AS Priority2
        , ISNULL((SELECT [Priority] FROM #Temp_Header96 WHERE RowID = 3),'') AS Priority3
        , ISNULL((SELECT [Priority] FROM #Temp_Header96 WHERE RowID = 4),'') AS Priority4
        , ISNULL((SELECT [Priority] FROM #Temp_Header96 WHERE RowID = 5),'') AS Priority5
        , ISNULL((SELECT [Priority] FROM #Temp_Header96 WHERE RowID = 6),'') AS Priority6
        , ISNULL((SELECT [Priority] FROM #Temp_Header96 WHERE RowID = 7),'') AS Priority7
        , ISNULL((SELECT [Priority] FROM #Temp_Header96 WHERE RowID = 8),'') AS Priority8
        , ISNULL((SELECT [Priority] FROM #Temp_Header96 WHERE RowID = 9),'') AS Priority9
        , ISNULL((SELECT [Priority] FROM #Temp_Header96 WHERE RowID = 10),'') AS Priority10
        --, LocAisle
        --, Loc
        --, SKU
        --, Descr
        --, Size
        --, SUM(Qty) AS Qty
      FROM #Temp_Detail96 
      --GROUP BY LocAisle, Loc, SKU, Descr, Size
      --ORDER BY LocAisle, Loc, SKU, Descr, Size
   END
   IF @c_otherparms = 'D'
   BEGIN
      SELECT ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 1),'') AS Orderkey1
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 1),'') AS Pickslipno1
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 2),'') AS Orderkey2
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 2),'') AS Pickslipno2
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 3),'') AS Orderkey3
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 3),'') AS Pickslipno3
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 4),'') AS Orderkey4
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 4),'') AS Pickslipno4
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 5),'') AS Orderkey5
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 5),'') AS Pickslipno5
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 6),'') AS Orderkey6
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 6),'') AS Pickslipno6
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 7),'') AS Orderkey7
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 7),'') AS Pickslipno7
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 8),'') AS Orderkey8
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 8),'') AS Pickslipno8
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 9),'') AS Orderkey9
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 9),'') AS Pickslipno9
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 10),'') AS Orderkey10
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 10),'') AS Pickslipno10
        , LocAisle
        , Loc
        , SKU
        , Descr
        , Size
        , OtherSKU
        , SUM(Qty) AS Qty
      FROM #Temp_Detail96 
      GROUP BY LocAisle, Loc, SKU, Descr, Size, OtherSKU
      ORDER BY LocAisle, Loc, SKU, Descr, Size, OtherSKU
   END
   ELSE IF @c_otherparms = 'H'
   BEGIN
      SELECT TOP 1 ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 1),'') AS Orderkey1
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 1),'') AS Pickslipno1
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 2),'') AS Orderkey2
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 2),'') AS Pickslipno2
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 3),'') AS Orderkey3
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 3),'') AS Pickslipno3
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 4),'') AS Orderkey4
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 4),'') AS Pickslipno4
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 5),'') AS Orderkey5
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 5),'') AS Pickslipno5
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 6),'') AS Orderkey6
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 6),'') AS Pickslipno6
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 7),'') AS Orderkey7
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 7),'') AS Pickslipno7
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 8),'') AS Orderkey8
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 8),'') AS Pickslipno8
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 9),'') AS Orderkey9
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 9),'') AS Pickslipno9
        , ISNULL((SELECT Orderkey FROM #Temp_Header96 WHERE RowID = 10),'') AS Orderkey10
        , ISNULL((SELECT Pickslipno FROM #Temp_Header96 WHERE RowID = 10),'') AS Pickslipno10
        , @c_UserID AS UserID
      FROM #Temp_Detail96 
   END
   ELSE IF @c_otherparms = 'Y'
   BEGIN
      DECLARE cur_Final CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT ORDERKEY, SUM(QTY) AS Qty
      FROM #Temp_Detail96
      WHERE LocAisle = @c_LocAisle
      AND LOC = @c_Loc     
      AND SKU = @c_SKU     
      AND Descr = @c_Descr   
      AND Size = @c_Size
      GROUP BY ORDERKEY
      
      OPEN cur_Final
      
      FETCH NEXT FROM cur_Final INTO @c_FoundOrderkey, @n_FoundQty
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE #Temp_Orderkey96
         SET FoundOrderkey = @c_FoundOrderkey,
             FoundQty      = @n_FoundQty
         WHERE Orderkey = @c_FoundOrderkey
         FETCH NEXT FROM cur_Final INTO @c_FoundOrderkey, @n_FoundQty
      END

      SELECT FoundOrderkey1 = ISNULL((SELECT FoundOrderkey FROM #Temp_Orderkey96 WHERE ROWID = 1),'')
           , FoundQty1      = ISNULL((SELECT FoundQty FROM #Temp_Orderkey96 WHERE ROWID = 1),0)
           , FoundOrderkey2 = ISNULL((SELECT FoundOrderkey FROM #Temp_Orderkey96 WHERE ROWID = 2),'')
           , FoundQty2      = ISNULL((SELECT FoundQty FROM #Temp_Orderkey96 WHERE ROWID = 2),0)
           , FoundOrderkey3 = ISNULL((SELECT FoundOrderkey FROM #Temp_Orderkey96 WHERE ROWID = 3),'')
           , FoundQty3      = ISNULL((SELECT FoundQty FROM #Temp_Orderkey96 WHERE ROWID = 3),0)
           , FoundOrderkey4 = ISNULL((SELECT FoundOrderkey FROM #Temp_Orderkey96 WHERE ROWID = 4),'')
           , FoundQty4      = ISNULL((SELECT FoundQty FROM #Temp_Orderkey96 WHERE ROWID = 4),0)
           , FoundOrderkey5 = ISNULL((SELECT FoundOrderkey FROM #Temp_Orderkey96 WHERE ROWID = 5),'')
           , FoundQty5      = ISNULL((SELECT FoundQty FROM #Temp_Orderkey96 WHERE ROWID = 5),0)
           , FoundOrderkey6 = ISNULL((SELECT FoundOrderkey FROM #Temp_Orderkey96 WHERE ROWID = 6),'')
           , FoundQty6      = ISNULL((SELECT FoundQty FROM #Temp_Orderkey96 WHERE ROWID = 6),0)
           , FoundOrderkey7 = ISNULL((SELECT FoundOrderkey FROM #Temp_Orderkey96 WHERE ROWID = 7),'')
           , FoundQty7      = ISNULL((SELECT FoundQty FROM #Temp_Orderkey96 WHERE ROWID = 7),0)
           , FoundOrderkey8 = ISNULL((SELECT FoundOrderkey FROM #Temp_Orderkey96 WHERE ROWID = 8),'')
           , FoundQty8      = ISNULL((SELECT FoundQty FROM #Temp_Orderkey96 WHERE ROWID = 8),0)
           , FoundOrderkey9 = ISNULL((SELECT FoundOrderkey FROM #Temp_Orderkey96 WHERE ROWID = 9),'')
           , FoundQty9      = ISNULL((SELECT FoundQty FROM #Temp_Orderkey96 WHERE ROWID = 9),0)
           , FoundOrderkey10 = ISNULL((SELECT FoundOrderkey FROM #Temp_Orderkey96 WHERE ROWID = 10),'')
           , FoundQty10     = ISNULL((SELECT FoundQty FROM #Temp_Orderkey96 WHERE ROWID = 10),0)

   END
   
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   
   IF CURSOR_STATUS('LOCAL' , 'cur_Final') in (0 , 1)
   BEGIN
      CLOSE cur_Final
      DEALLOCATE cur_Final   
   END

   IF CURSOR_STATUS('LOCAL' , 'cur_ReArrange') in (0 , 1)
   BEGIN
      CLOSE cur_ReArrange
      DEALLOCATE cur_ReArrange   
   END

   IF OBJECT_ID('tempdb..#Temp_Header96') IS NOT NULL
      DROP TABLE #Temp_Header96

   IF OBJECT_ID('tempdb..#Temp_Detail96') IS NOT NULL
      DROP TABLE #Temp_Detail96

   IF OBJECT_ID('tempdb..#Temp_Orderkey96') IS NOT NULL
      DROP TABLE #Temp_Orderkey96

END

GO