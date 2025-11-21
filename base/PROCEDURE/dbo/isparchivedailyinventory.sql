SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      

        
/************************************************************************/        
/* Stored Proc : ispArchiveDailyInventory                               */        
/* Creation Date: 27.Aug.2008                                           */        
/* Copyright: IDS                                                       */        
/* Written by: Shong                                                    */        
/*                                                                      */        
/* Purpose: Housekeeping DailyInventory table                           */        
/*                                                                      */        
/* Input Parameters: Days, TargetDB, ArchiveDB                          */        
/*                                                                      */        
/* Output Parameters: NONE                                              */        
/*                                                                      */        
/* Return Status: NONE                                                  */        
/*                                                                      */        
/* Usage:                                                               */        
/*                                                                      */        
/* Local Variables:                                                     */        
/*                                                                      */        
/* Called By: SQL Schedule Task                                         */        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 5.4                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author        Purposes                                  */        
/* 28-AUG-2008  Leong         SOS#114679 - Change fix db to parameters  */        
/*                            pass in                                   */        
/* 15-Jul-2010  TLTING        Order by by Invneotry Date                */     
/* 23-Dec-2011  TLTING        Cater SKU code with '                     */
/************************************************************************/       
       
CREATE PROC [dbo].[ispArchiveDailyInventory]        
 @nDayRetains  int        
  , @cTargetDBName  NVARCHAR(20)         
  , @c_ArchiveDBName NVARCHAR(20)         
AS        
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF         
   SET ANSI_NULLS OFF         
        
DECLARE  @dBeforeDate  datetime        
    , @cSKU    NVARCHAR(20)        
    , @cLOC    NVARCHAR(10)        
    , @cID    NVARCHAR(18)        
    , @dInventoryDate datetime         
    , @cStorerKey  NVARCHAR(15)        
    , @nContinue   int        
    , @cRecCount   int        
    , @b_debug int        
       , @c_ExecStatements nvarchar(4000)        
    , @c_ExecArguments nvarchar(4000)        
        
SET @b_debug = 0        
SET @nContinue = 1        
SET @nDayRetains = @nDayRetains * -1        
SET @dBeforeDate = DateAdd(day, @nDayRetains, GetDate())        
        
-- SOS#114679        
--   DECLARE curDailyInventory CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
--   SELECT Storerkey, Sku, Loc, Id, InventoryDate        
--   FROM DailyInventory WITH (NOLOCK)        
--   WHERE InventoryDate < @dBeforeDate        
        
      SET @c_ExecStatements = N'DECLARE curDailyInventory CURSOR FAST_FORWARD READ_ONLY FOR '          
                              + 'SELECT Storerkey, Sku, Loc, Id, InventoryDate  '        
                              + 'FROM ' + ISNULL(RTRIM(@cTargetDBName),'')         
                           + '.dbo.DailyInventory WITH (NOLOCK) '         
                              + 'WHERE InventoryDate < ''' + convert(char(10), @dBeforeDate, 120) + ''''        
                              + ' GROUP BY InventoryDate, Storerkey, Sku, Loc, Id '      
                --+ 'ORDER BY InventoryDate, Storerkey, Sku, Loc, Id '      
        
      SET @c_ExecArguments = N'@cTargetDBName NVARCHAR(20), ' +         
                              '@dBeforeDate datetime '         
        
  IF @b_debug = 1        
  BEGIN           
     PRINT @c_ExecStatements        
  END         
        
      EXEC sp_ExecuteSql @c_ExecStatements         
                       , @c_ExecArguments          
                       , @cTargetDBName         
                       , @dBeforeDate         
        
      OPEN curDailyInventory        
      FETCH NEXT FROM curDailyInventory INTO @cStorerkey, @cSku, @cLoc, @cId, @dInventoryDate        
        
WHILE @@FETCH_STATUS <> -1        
BEGIN        
        
        
 SET @c_ExecStatements =         
    N' SELECT @cRecCount = COUNT(1) ' +        
     ' FROM ' + ISNULL(RTRIM(@c_ArchiveDBName), '') + '.dbo.DailyInventory WITH (NOLOCK) WHERE ' +        
     ' Storerkey = N''' + ISNULL(RTRIM(@cStorerkey), '') + ''' AND ' +        
     ' Sku = ''' + ISNULL(RTRIM(@cSku), '') + ''' AND ' +        
     ' Loc = N''' + ISNULL(RTRIM(@cLOC), '') + ''' AND ' +         
     ' Id  = N''' + ISNULL(RTRIM(@cId), '') + ''' AND ' +          
     ' InventoryDate = ''' + convert(char(10), @dInventoryDate, 120) + ''''        
  IF @b_debug = 1        
  BEGIN           
     PRINT @c_ExecStatements        
  END          
 SET @c_ExecArguments =        
      N'@cRecCount NVARCHAR(10) OUTPUT, ' +        
      '@cStorerkey  NVARCHAR(20), ' +         
      '@cSku  NVARCHAR(20), ' +         
      '@cLOC  NVARCHAR(10), ' +        
      '@cId  NVARCHAR(18), ' +        
      '@dInventoryDate  datetime '        
        
 EXEC sp_ExecuteSql @c_ExecStatements        
       ,@c_ExecArguments        
       ,@cRecCount OUTPUT        
       ,@cStorerkey        
       ,@cSku        
       ,@cLOC        
           ,@cId         
       ,@dInventoryDate        
        
      IF @@ERROR <> 0         
      BEGIN        
         SET @nContinue = 3        
         BREAK         
      END        
        
 IF @b_debug = 1        
 BEGIN        
  SELECT @cRecCount '@cRecCount', @c_ExecStatements 'Count Records from Archive DailyInventory'        
 END        
        
-- SOS#114679        
--   IF NOT EXISTS(SELECT 1 FROM DailyInventory WHERE         
--                 Storerkey= @cStorerkey AND        
--                 Sku = @cSku AND        
--                 Loc = @cLOC AND        
--                 Id  = @cId AND        
--                 InventoryDate = @dInventoryDate)        
        
IF ISNULL(CAST(@cRecCount AS Int),0) <= 0        
   BEGIN    
      
 SET @c_ExecStatements =         
    N'INSERT INTO ' + ISNULL(RTRIM(@c_ArchiveDBName), '') + '.dbo.DailyInventory ( ' +        
     ' [Storerkey],    [Sku],                [Loc], ' +        
     ' [Id],           [Qty],                [InventoryDate], ' +        
     ' [Adddate],      [Addwho],             [Editdate], ' +        
     ' [Editwho],      [InventoryCBM],       [InventoryPallet], ' +        
     ' [CommingleSku], [SkuInventoryPallet], [SkuChargingPallet] )' +        
     ' SELECT  ' +        
     ' [Storerkey],    [Sku],                [Loc], ' +        
     ' [Id],           [Qty],                [InventoryDate], ' +        
     ' [Adddate],      [Addwho],             [Editdate], ' +        
     ' [Editwho],      [InventoryCBM],       [InventoryPallet], ' +        
     ' [CommingleSku], [SkuInventoryPallet], [SkuChargingPallet] ' +        
     ' FROM ' + ISNULL(RTRIM(@cTargetDBName), '') + '.dbo.DailyInventory WITH (NOLOCK) WHERE ' +        
     ' Storerkey = N''' + ISNULL(RTRIM(@cStorerkey), '') + ''' AND ' +        
     ' Sku = N''' + ISNULL(RTRIM(@cSku), '') + ''' AND ' +        
     ' Loc = N''' + ISNULL(RTRIM(@cLOC), '') + ''' AND ' +         
     ' Id  = ''' + ISNULL(RTRIM(@cId), '') + ''' AND ' +        
     ' InventoryDate = ''' + convert(char(10), @dInventoryDate, 120) + ''''        
--     ' InventoryDate = ''' + ISNULL(RTRIM(@dInventoryDate), '')+ ''''        
        
 SET @c_ExecArguments =         
      N'@cStorerkey  NVARCHAR(20), ' +         
      '@cSku  NVARCHAR(20), ' +         
      '@cLOC  NVARCHAR(10), ' +      
      '@cId  NVARCHAR(18), ' +        
      '@dInventoryDate  datetime '        
   
   BEGIN TRAN       
 EXEC sp_ExecuteSql @c_ExecStatements        
       ,@c_ExecArguments         
       ,@cStorerkey        
       ,@cSku        
       ,@cLOC        
           ,@cId         
       ,@dInventoryDate         
        
      IF @@ERROR <> 0         
      BEGIN        
         SET @nContinue = 3        
         ROLLBACK TRAN  
         BREAK         
      END        
      COMMIT TRAN   
   END        
        
-- SOS#114679        
--   IF EXISTS(SELECT 1 FROM DailyInventory WHERE         
--                 Storerkey= @cStorerkey AND        
--                 Sku = @cSku AND        
--                 Loc = @cLOC AND        
--                 Id  = @cId AND        
--                 InventoryDate = @dInventoryDate)        
 SET @c_ExecStatements =         
    N' SELECT @cRecCount = COUNT(1)  ' +        
     ' FROM ' + ISNULL(RTRIM(@cTargetDBName), '') + '.dbo.DailyInventory WITH (NOLOCK) WHERE ' +        
     ' Storerkey = N''' + ISNULL(RTRIM(@cStorerkey), '') + ''' AND ' +        
     ' Sku = N''' + ISNULL(RTRIM(@cSku), '') + ''' AND ' +        
     ' Loc = N''' + ISNULL(RTRIM(@cLOC), '') + ''' AND ' +         
     ' Id  = N''' + ISNULL(RTRIM(@cId), '') + ''' AND ' +          
     ' InventoryDate = ''' + convert(char(10), @dInventoryDate, 120) + ''''        
--     ' InventoryDate = ''' + ISNULL(RTRIM(@dInventoryDate), '')+ ''''        
        
 SET @c_ExecArguments =        
      N'@cRecCount NVARCHAR(10) OUTPUT, ' +        
      '@cStorerkey  NVARCHAR(20), ' +         
      '@cSku  NVARCHAR(20), ' +         
      '@cLOC  NVARCHAR(10), ' +        
      '@cId  NVARCHAR(18), ' +        
      '@dInventoryDate  datetime '        
        
 EXEC sp_ExecuteSql @c_ExecStatements        
       ,@c_ExecArguments        
       ,@cRecCount OUTPUT         
       ,@cStorerkey        
       ,@cSku        
       ,@cLOC        
           ,@cId         
       ,@dInventoryDate        
 IF @b_debug = 1        
 BEGIN        
  SELECT @cRecCount '@cRecCount', @c_ExecStatements 'Count Records from DailyInventory To Delete after archiving'        
 END        
        
IF ISNULL(CAST(@cRecCount AS Int),0) > 0        
   BEGIN        
-- SOS#114679        
--      DELETE FROM DailyInventory WITH (ROWLOCK)        
--      WHERE Storerkey= @cStorerkey AND        
--      Sku = @cSku AND        
--      Loc = @cLOC AND        
--      Id  = @cId AND        
--      InventoryDate = @dInventoryDate        
        
 SET @c_ExecStatements =         
    N' DELETE ' +        
     ' FROM ' + ISNULL(RTRIM(@cTargetDBName), '') + '.dbo.DailyInventory WITH (ROWLOCK) WHERE ' +        
     ' Storerkey = N''' + ISNULL(RTRIM(@cStorerkey), '') + ''' AND ' +        
     ' Sku = N''' + ISNULL(RTRIM(@cSku), '') + ''' AND ' +        
     ' Loc = N''' + ISNULL(RTRIM(@cLOC), '') + ''' AND ' +         
     ' Id  = N''' + ISNULL(RTRIM(@cId), '') + ''' AND ' +          
     ' InventoryDate = ''' + convert(char(10), @dInventoryDate, 120) + ''''        
--     ' InventoryDate = ''' + ISNULL(RTRIM(@dInventoryDate), '')+ ''''        
      
        
 SET @c_ExecArguments =        
      N'@cStorerkey  NVARCHAR(20), ' +         
      '@cSku  NVARCHAR(20), ' +         
      '@cLOC  NVARCHAR(10), ' +        
      '@cId  NVARCHAR(18), ' +        
      '@dInventoryDate  datetime '        
        
 IF @b_debug = 1        
 BEGIN        
  SELECT @c_ExecStatements 'Delete from DailyInventory'        
 END        
 BEGIN TRAN       
 EXEC sp_ExecuteSql @c_ExecStatements        
       ,@c_ExecArguments        
       ,@cStorerkey        
       ,@cSku        
       ,@cLOC        
           ,@cId         
       ,@dInventoryDate        
        
      IF @@ERROR <> 0        
      BEGIN        
         SET @nContinue = 3        
         BREAK   
         ROLLBACK  TRAN      
      END         
      COMMIT TRAN  
   END         
        
   WHILE @@TRANCOUNT > 0        
      COMMIT TRAN         
        
   FETCH NEXT FROM curDailyInventory INTO @cStorerkey, @cSku, @cLoc, @cId, @dInventoryDate        
END -- While        
        
CLOSE curDailyInventory        
DEALLOCATE curDailyInventory        
        
IF @nContinue = 3        
   ROLLBACK TRAN 
   

GO