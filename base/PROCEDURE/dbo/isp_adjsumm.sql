SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_adjsumm                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Change to call SP for Customize                             */
/*        : SOS#300038 - [GIGA] Change request on View Report -         */
/*          Stock Adjustment Summary                                    */
/*                                                                      */
/* Input Parameters:  @dt_AdjustDateStart  - Effectivedate Key          */
/*                 ,  @dt_AdjustDateend  - Effectivedate Key            */
/*                 ,  @c_facilitystart  - Facility Key                  */
/*                 ,  @c_facilityend    - Facility Key                  */
/*                 ,  @c_adjustmentkeystart - adjustment Key            */
/*                 ,  @c_adjustmentkeyend   - adjustment Key            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_adjusment_summary                  */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_adjsumm] (
      @dt_AdjustDateStart     DATETIME
   ,  @dt_AdjustDateEnd       DATETIME
   ,  @c_FacilityStart        NVARCHAR(5)
   ,  @c_FacilityEnd          NVARCHAR(5)
   ,  @c_AdjustmentkeyStart   NVARCHAR(10)
   ,  @c_AdjustmentkeyEnd     NVARCHAR(10)
)
 AS
BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @n_continue       INT 
         ,  @c_errmsg         NVARCHAR(255) 
         ,  @b_success        INT 
         ,  @n_err            INT 
         ,  @n_StartTCnt      INT

         ,  @c_SQL            NVARCHAR(MAX)
         ,  @c_Storerkey      NVARCHAR(15)


         ,  @n_UDF01IsCol     INT
         ,  @n_UDF02IsCol     INT
         ,  @n_UDF03IsCol     INT

         ,  @n_CombineSku     INT
         ,  @c_UDF01          NVARCHAR(30)
         ,  @c_UDF02          NVARCHAR(30) 
         ,  @c_UDF03          NVARCHAR(30) 
         ,  @c_TableName      NVARCHAR(30) 

   SET @n_StartTCnt = @@TRANCOUNT
     
   CREATE TABLE #TMP_ADJ
      (
         Adjustmentkey     NVARCHAR(10)   NULL
      ,  StorerKey         NVARCHAR(15)   NULL
      ,  EffectiveDate     DATETIME       NULL
      ,  Sku               NVARCHAR(20)   NULL
      ,  Loc               NVARCHAR(10)   NULL
      ,  Lot               NVARCHAR(10)   NULL
      ,  AdjustmentType    NVARCHAR(3)   NULL
      ,  Id                NVARCHAR(18)   NULL
      ,  ReasonCode        NVARCHAR(10)   NULL
      ,  Qty               INT            NULL

      ,  SKUDescr          NVARCHAR(60)   NULL
      ,  Facility          NVARCHAR(5)    NULL
      )

   INSERT INTO #TMP_ADJ
      (  Adjustmentkey
      ,  StorerKey     
      ,  EffectiveDate 
      ,  Sku           
      ,  Loc 
      ,  Lot
      ,  AdjustmentType
      ,  ID    
      ,  ReasonCode          
      ,  Qty 
      ,  SKUDescr  
      ,  Facility     
      )

  SELECT ADJUSTMENT.AdjustmentKey 
       , ADJUSTMENT.StorerKey 
       , ADJUSTMENT.EffectiveDate 
       , ADJUSTMENTDETAIL.Sku 
       , ADJUSTMENTDETAIL.Loc 
       , ADJUSTMENTDETAIL.Lot
		 ,	ADJUSTMENT.AdjustmentType 
       , ADJUSTMENTDETAIL.Id 
       , ADJUSTMENTDETAIL.ReasonCode 
       , ADJUSTMENTDETAIL.Qty 
	    ,	SKU.DESCR
       , LOC.Facility 
    FROM ADJUSTMENT WITH (NOLOCK) 
	 JOIN ADJUSTMENTDETAIL WITH (NOLOCK)ON ( ADJUSTMENT.AdjustmentKey = ADJUSTMENTDETAIL.AdjustmentKey ) 
	 JOIN LOC              WITH(NOLOCK) ON (ADJUSTMENTDETAIL.Loc = LOC.Loc)
	 JOIN SKU              WITH(NOLOCK) ON (ADJUSTMENTDETAIL.StorerKey = SKU.StorerKey)
                                       AND(ADJUSTMENTDETAIL.Sku = SKU.Sku) 
	WHERE (ADJUSTMENT.AdjustmentKey >= @c_AdjustmentkeyStart)    
   AND   (ADJUSTMENT.AdjustmentKey <= @c_AdjustmentkeyEnd)    
   AND   (ADJUSTMENT.EffectiveDate >= @dt_AdjustDateStart)  
   AND   (ADJUSTMENT.EffectiveDate < DateAdd(day,1, @dt_AdjustDateEnd))   
   AND   (LOC.Facility >= @c_FacilityStart) 
   AND   (LOC.Facility <= @c_FacilityEnd) 

   
   DECLARE CUR_STR CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT   DISTINCT Storerkey                                
   FROM #TMP_ADJ  

   OPEN CUR_STR
   
   FETCH NEXT FROM CUR_STR INTO  @c_Storerkey                                        
                             
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_UDF01 = ''
      SET @c_UDF02 = ''
      SET @c_UDF03 = ''
      SET @n_CombineSku = 0
     
      SELECT @c_UDF01 = ISNULL(UDF01,'')
            ,@c_UDF02 = ISNULL(UDF02,'')
            ,@c_UDF03 = ISNULL(UDF03,'')
            ,@n_CombineSku = 1
      FROM CODELKUP WITH (NOLOCK)
      WHERE Listname = 'COMBINESKU'
      AND Code = 'CONCATENATESKU'
      AND Storerkey = @c_Storerkey   
      
      IF @n_CombineSku = 1
      BEGIN
         SET @c_TableName = ''
         SET @c_TableName = CASE WHEN CHARINDEX('.', @c_UDF01) > 0 
                                 THEN SUBSTRING(@c_UDF01, 1, CHARINDEX('.', @c_UDF01)-1)
                                 WHEN CHARINDEX('.', @c_UDF02) > 0 
                                 THEN SUBSTRING(@c_UDF02, 1, CHARINDEX('.', @c_UDF02)-1)
                                 WHEN CHARINDEX('.', @c_UDF03) > 0 
                                 THEN SUBSTRING(@c_UDF03, 1, CHARINDEX('.', @c_UDF03)-1)
                                 ELSE 'SKU'
                                 END

         SET @c_UDF01 = CASE WHEN CHARINDEX('.', @c_UDF01) > 0 
                             THEN SUBSTRING(@c_UDF01, CHARINDEX('.', @c_UDF01)+1, LEN(@c_UDF01) - CHARINDEX('.', @c_UDF01))
                             ELSE @c_UDF01
                             END

         SET @c_UDF02 = CASE WHEN CHARINDEX('.', @c_UDF02) > 0 
                             THEN SUBSTRING(@c_UDF02, CHARINDEX('.', @c_UDF02)+1, LEN(@c_UDF02) - CHARINDEX('.', @c_UDF02))
                             ELSE @c_UDF02
                             END

         SET @c_UDF03 = CASE WHEN CHARINDEX('.', @c_UDF03) > 0 
                             THEN SUBSTRING(@c_UDF03, CHARINDEX('.', @c_UDF03)+1, LEN(@c_UDF03) - CHARINDEX('.', @c_UDF03))
                             ELSE @c_UDF03
                             END

         SET @n_UDF01IsCol = 0
         SET @n_UDF02IsCol = 0
         SET @n_UDF03IsCol = 0

         SELECT @n_UDF01IsCol =  MAX(CASE WHEN COLUMN_NAME = @c_UDF01 THEN 1 ELSE 0 END)
               ,@n_UDF02IsCol =  MAX(CASE WHEN COLUMN_NAME = @c_UDF02 THEN 1 ELSE 0 END)
               ,@n_UDF03IsCol =  MAX(CASE WHEN COLUMN_NAME = @c_UDF03 THEN 1 ELSE 0 END)
         FROM   INFORMATION_SCHEMA.COLUMNS 
         WHERE  TABLE_NAME = @c_TableName


         SET @c_UDF01 = CASE WHEN @n_UDF01IsCol = 1 
                             THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF01 + ')'
                             ELSE '''' + @c_UDF01 + ''''
                             END

         SET @c_UDF02 = CASE WHEN @n_UDF02IsCol = 1 
                             THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF02 + ')'
                             ELSE '''' + @c_UDF02 + ''''
                             END

         SET @c_UDF03 = CASE WHEN @n_UDF03IsCol = 1 
                             THEN 'RTRIM(' + @c_TableName + '.' + @c_UDF03 + ')'
                             ELSE '''' + @c_UDF03 + ''''
                             END

         SET @c_SQL = ''
         SET @c_SQL = N' UPDATE #TMP_ADJ'
                    +  ' SET SKU = ' + @c_UDF01 + ' + ' + @c_UDF02 + ' + ' + @c_UDF03
                    +  ' FROM  #TMP_ADJ TMP '
                    +  ' JOIN ' + @c_TableName + ' WITH (NOLOCK) ON  TMP.Storerkey = SKU.Storerkey'
                    +                                          ' AND TMP.Sku = SKU.Sku' 
                    +  ' WHERE TMP.Storerkey = ''' + @c_storerkey + ''''
      
         EXEC ( @c_SQL )
      END
      FETCH NEXT FROM CUR_STR INTO  @c_Storerkey 
   END
   CLOSE CUR_STR
   DEALLOCATE CUR_STR

   QUIT_SP:
   SELECT Adjustmentkey
      ,  StorerKey     
      ,  EffectiveDate 
      ,  Sku           
      ,  Loc 
      ,  Lot
      ,  AdjustmentType
      ,  ID    
      ,  ReasonCode          
      ,  Qty 
      ,  SKUDescr  
      ,  Facility        
   FROM #TMP_ADJ 

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN 

   /* #INCLUDE <SPTPA01_2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_adjsumm'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END

END

GO