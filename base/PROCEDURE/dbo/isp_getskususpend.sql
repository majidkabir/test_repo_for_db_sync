SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/ 
/* Object Name: isp_GetSKUSuspend                                          */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/***************************************************************************/    
CREATE PROC [dbo].[isp_GetSKUSuspend]  
@c_Storerkey Nvarchar(15),
@n_ActivePeriod INT = '0',
@n_DMCheckFlag INT = '0'         
AS          
BEGIN           
        
   SET NOCOUNT ON          
   SET ANSI_NULLS ON           
   SET ANSI_WARNINGS ON   
   SET QUOTED_IDENTIFIER OFF

   DECLARE @c_Sku       Nvarchar(20)
   DECLARE @c_DMServerName NVarchar(100)
   DECLARE @b_debug INT
   DECLARE @c_ExecStatements  nvarchar(4000)
   DECLARE @c_ExecArguments   nvarchar(4000)

   SET @b_debug = 0

   IF ISNULL(RTRIM(@c_Storerkey), '')  = '' 
    BEGIN 
       PRINT 'Storerkey is must!'
       GOTO Quit
    END
      
   IF @n_ActivePeriod IS NULL OR @n_ActivePeriod = 0
    BEGIN 
       PRINT 'SKU Active Period required!'
       GOTO Quit
    END
    
    IF @n_DMCheckFlag = '1'
    BEGIN

      SELECT @c_DMServerName = NSQLDescrip 
      FROM dbo.NSQLCONFIG WITH (NOLOCK)
      WHERE ConfigKey = 'DataMartServerDBName'
            
      IF ISNULL(RTRIM(@c_DMServerName), '')  = '' 
      BEGIN 
         PRINT 'Datamart Connection not setup!'
         SET @n_DMCheckFlag = '0' 
      END
   END
                   
   Create TABLE #DM_SKU
     ( Rowref     INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
      Storerkey   NVARCHAR(15),
      SKU         Nvarchar(20) )


   IF @n_DMCheckFlag = '1'
   BEGIN
      --   SKU (DM), with Stock or ITRN
      SET @c_ExecStatements = N' SELECT S.Storerkey, S.SKU ' + CHAR(13) +
                                 N' FROM ' + RTRIM(@c_DMServerName) + '.ODS.SKU S (NOLOCK)  ' + CHAR(13) +
                                 N' WHERE StorerKey = ''' + RTRIM(@c_Storerkey) +'''  ' + CHAR(13) +
                                 N' AND ( EXISTS ( Select 1 FROM ' + RTRIM(@c_DMServerName) + '.ODS.ITRN  I (NOLOCK) ' + CHAR(13) + 
                                 N' Where I.Storerkey = S.storerkey and I.SKU = S.SKU ' + CHAR(13) + 
                                 N' AND I.Adddate > CONVERT(DATETIME, CONVERT(char(11), getdate() - ' + RTRIM(@n_ActivePeriod) + ', 112 ) ) ) ' + CHAR(13) + 
                                 N' OR EXISTS ( Select 1 FROM ' + RTRIM(@c_DMServerName) + '.ODS.SKUXLOC  I (NOLOCK) ' + CHAR(13) + 
                                 N' Where I.Storerkey = S.storerkey and I.SKU = S.SKU ' + CHAR(13) + 
                                 N' AND I.qty > 0 ) ) '  
                                 
      IF @b_debug = 1
      BEGIN
       PRINT @c_ExecStatements
      END
       
      INSERT INTO #DM_SKU (Storerkey, SKU)
      EXEC ( @c_ExecStatements )  
   END
   
   -- Active SKU, No Stock, No ITRN, (DM)
   DECLARE Cur_SKUITEM CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT S.SKU 
   FROM  SKU S (NOLOCK)  
      WHERE S.Storerkey = @c_StorerKey
       AND S.SKUStatus = 'ACTIVE'  
       AND NOT EXISTS ( Select 1 FROM ITRN  I (NOLOCK)  
                      Where I.Storerkey = S.storerkey and I.SKU = S.SKU  
                      AND I.Adddate > CONVERT(DATETIME, CONVERT(char(11), (GETDATE() - @n_ActivePeriod) , 112 ) ) )
       AND NOT EXISTS ( Select 1 FROM SKUXLOC  I (NOLOCK) 
                      Where I.Storerkey = S.storerkey and I.SKU = S.SKU 
                      AND I.qty > 0 )  
       AND NOT EXISTS ( Select 1 FROM #DM_SKU  I (NOLOCK) 
                      Where I.Storerkey = S.storerkey and I.SKU = S.SKU )                             

   OPEN Cur_SKUITEM

   FETCH NEXT FROM Cur_SKUITEM INTO @c_Sku

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT 'SKU Deactivate - ' + @c_Sku
      END

      BEGIN TRAN
      UPDATE SKU with (ROWLOCK)
      SET SKUStatus = 'INACTIVE', editdate = getdate() 
      WHERE Storerkey = @c_StorerKey
        AND SKU = @c_Sku
      IF @@ERROR = 0
      BEGIN
         COMMIT TRAN
      END
      ELSE
      BEGIN
         ROLLBACK TRAN
         GOTO Quit
      END

      FETCH NEXT FROM Cur_SKUITEM INTO @c_Sku

   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE Cur_SKUITEM
   DEALLOCATE Cur_SKUITEM
    
   -- Inactive SKU, With Stock, and ITRN, (DM)
   DECLARE Cur_SKUITEM CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT S.SKU 
   FROM   SKU S (NOLOCK)  
      WHERE S.Storerkey = @c_StorerKey
      AND S.SKUStatus = 'INACTIVE'
      AND ( EXISTS ( Select 1 FROM ITRN  I (NOLOCK)   
                     Where I.Storerkey = S.storerkey and I.SKU = S.SKU  
                     AND I.Adddate < CONVERT(DATETIME, CONVERT(char(11), getdate() - @n_ActivePeriod, 112 ) ) )  
         OR EXISTS ( Select 1 FROM  SKUXLOC  I (NOLOCK)   
                     Where I.Storerkey = S.storerkey and I.SKU = S.SKU    
                     AND I.qty > 0 ) 
         OR EXISTS ( Select 1 FROM #DM_SKU  I (NOLOCK) 
                   Where I.Storerkey = S.storerkey and I.SKU = S.SKU )               ) 
      
   OPEN Cur_SKUITEM

   FETCH NEXT FROM Cur_SKUITEM INTO @c_Sku

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug = 1
      BEGIN
         SELECT 'SKU Activate Now - ' + @c_Sku
      END

      BEGIN TRAN
      UPDATE SKU with (ROWLOCK)
      SET SKUStatus = 'ACTIVE', editdate = getdate()  
      WHERE Storerkey = @c_StorerKey
        AND SKU = @c_Sku

      IF @@ERROR = 0
      BEGIN
         COMMIT TRAN
      END
      ELSE
      BEGIN
         ROLLBACK TRAN
         GOTO Quit
      END

      FETCH NEXT FROM Cur_SKUITEM INTO @c_Sku

   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE Cur_SKUITEM
   DEALLOCATE Cur_SKUITEM
    

QUIT:
 
RETURN

END

GO