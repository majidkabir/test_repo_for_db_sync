SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/      
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_005_1                           */      
/* Creation Date: 30-May-2022                                              */      
/* Copyright: LFL                                                          */      
/* Written by: WLChooi                                                     */      
/*                                                                         */      
/* Purpose: WMS-19758 - [TW] JET Pick Slip CR                              */      
/*                                                                         */      
/* Called By: RPT_WV_PLIST_WAVE_005_1                                      */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */    
/* 30-May-2022  WLChooi  1.0   DevOps Combine Script                       */  
/***************************************************************************/  
CREATE PROC [dbo].[isp_RPT_WV_PLIST_WAVE_005_1]  
      @c_Orderkey NVARCHAR(10)
    , @c_LOC      NVARCHAR(20)
    , @c_Style    NVARCHAR(20)
    , @c_Color    NVARCHAR(20)
                
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @n_Continue     INT = 1
         , @c_Size         NVARCHAR(10)
         , @n_Qty          INT
         , @n_CurrRow      INT = 0
         , @c_CurrRow      NVARCHAR(2) = ''
         , @c_SQL          NVARCHAR(MAX) = ''

   CREATE TABLE #TMP_SIZE (
      Size01      NVARCHAR(10) NULL
    , Size02      NVARCHAR(10) NULL
    , Size03      NVARCHAR(10) NULL
    , Size04      NVARCHAR(10) NULL
    , Size05      NVARCHAR(10) NULL
    , Size06      NVARCHAR(10) NULL
    , Size07      NVARCHAR(10) NULL
    , Size08      NVARCHAR(10) NULL
    , Size09      NVARCHAR(10) NULL
    , Size10      NVARCHAR(10) NULL
    , Qty01       INT NULL
    , Qty02       INT NULL
    , Qty03       INT NULL
    , Qty04       INT NULL
    , Qty05       INT NULL
    , Qty06       INT NULL
    , Qty07       INT NULL
    , Qty08       INT NULL
    , Qty09       INT NULL
    , Qty10       INT NULL
   )

   --Insert Dummy Row
   INSERT INTO #TMP_SIZE
   VALUES
   (   NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
       NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
   )

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SKU.Size
        , Qty = ISNULL(SUM(PICKDETAIL.Qty),0)
   FROM PICKDETAIL WITH (NOLOCK)
   JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)
                         AND (PICKDETAIL.Sku = SKU.Sku)
   WHERE PICKDETAIL.Orderkey = @c_Orderkey
   AND PICKDETAIL.Loc = @c_LOC
   AND SKU.Style = @c_Style
   AND SKU.Color = @c_Color
   GROUP BY SKU.Size
   ORDER BY SKU.Size

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Size, @n_Qty

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_CurrRow = @n_CurrRow + 1
      SET @c_CurrRow = RIGHT('00' + CAST(@n_CurrRow AS NVARCHAR(2)), 2)

      SET @c_SQL = 'UPDATE #TMP_SIZE ' + CHAR(13)
                 + 'SET Size' + @c_CurrRow + ' = @c_Size '
                 + '  , Qty' + @c_CurrRow + ' = @n_Qty '

      EXEC sp_executesql @c_SQL,
      N'@c_Size NVARCHAR(10), @n_Qty INT', 
      @c_Size,
      @n_Qty 

      SET @c_CurrRow = ''

      FETCH NEXT FROM CUR_LOOP INTO @c_Size, @n_Qty
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   SELECT Size01
        , Size02
        , Size03
        , Size04
        , Size05
        , Size06
        , Size07
        , Size08
        , Size09
        , Size10
        , Qty01 
        , Qty02 
        , Qty03 
        , Qty04 
        , Qty05 
        , Qty06 
        , Qty07 
        , Qty08 
        , Qty09 
        , Qty10 
   FROM #TMP_SIZE

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF OBJECT_ID('tempdb..#TMP_SIZE') IS NOT NULL
      DROP TABLE #TMP_SIZE
END  

GO