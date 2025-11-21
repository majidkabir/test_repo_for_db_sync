SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store Procedure: isp_ReTriggerTransmitLog_MovePickDetail             */    
/* Creation Date:11-FEB-2020                                            */    
/* Copyright: IDS                                                       */    
/* Written by: LFL                                                      */    
/*                                                                      */    
/* Purpose: - To move archived pickdetail back to live db.              */    
/*          - Orders & OrderDetail must exists in live db before move   */    
/*            archived pickdetail record.                               */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Modifications:                                                       */    
/* Date         Author    Ver.  Purposes                                */    
/* 25-FEB-2022  CSCHONG   1.0    Devops Scripts Combine                 */   
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_ReTriggerTransmitLog_MovePickDetail]    
     @c_SourceDB    NVARCHAR(30)    
   , @c_TargetDB    NVARCHAR(30)    
   , @c_TableSchema NVARCHAR(10)    
   , @c_TableName   NVARCHAR(50)    
   , @c_KeyColumn   NVARCHAR(50) -- PickDetailKey / OrderKey    
   , @c_DocKey      NVARCHAR(50)    
   , @b_Success     int           OUTPUT    
   , @n_err         int           OUTPUT    
   , @c_errmsg      NVARCHAR(250) OUTPUT    
   , @b_Debug       INT = 0    
AS    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
DECLARE @c_SQL           NVARCHAR(MAX)    
      , @c_StorerKey     NVARCHAR(15)    
      , @c_Sku           NVARCHAR(20)    
      , @c_Lot           NVARCHAR(10)    
      , @c_Loc           NVARCHAR(10)    
      , @c_Id            NVARCHAR(18)    
      , @c_PackKey       NVARCHAR(10)    
      , @c_ValidFlag     NVARCHAR(1)    
      , @c_ArchiveCop    NVARCHAR(1)    
      , @n_DummyQty      INT    
      , @c_ExecArguments NVARCHAR(MAX)    
      , @b_RecFound      INT    
   , @n_continue      int     
   , @n_StartTCnt     INT     
   , @c_PickDetailKey NVARCHAR(20)    
    
    
   SELECT @n_continue=1    
    
SET @c_ArchiveCop = NULL    
SET @n_DummyQty   = '0'    
    
SET @c_StorerKey = ''    
SET @c_Sku       = ''    
SET @c_Lot       = ''    
SET @c_Loc       = ''    
SET @c_Id        = ''    
    
IF ISNULL(OBJECT_ID('tempdb..#PD'),'') <> ''    
BEGIN    
   DROP TABLE #PD    
END    
    
IF ISNULL(OBJECT_ID('tempdb..#ARPICKDET'),'') <> ''    
BEGIN    
   DROP TABLE #ARPICKDET    
END    
    
CREATE TABLE #PD (    
     StorerKey NVARCHAR(15) NULL    
   , Sku       NVARCHAR(20) NULL    
   , Lot       NVARCHAR(10) NULL    
   , Loc       NVARCHAR(10) NULL    
   , Id        NVARCHAR(18) NULL    
   )    
    
   CREATE TABLE #ARPICKDET (    
     PickDetailKey NVARCHAR(20) NULL,    
  Orderkey      NVARCHAR(20) NULL    
     )    
    
IF ISNULL(RTRIM(@c_KeyColumn),'') NOT IN ('PickDetailKey','OrderKey')    
BEGIN    
    SELECT @n_Continue = 3      
 SET @n_err = 700009    
    SELECT @c_errmsg = 'Invalid Table Key Column: ' + ISNULL(RTRIM(@c_KeyColumn),'') + '. (isp_ReTriggerTransmitLog_MovePickDetail)'    
   GOTO QUIT    
END    
    
IF @c_KeyColumn = 'PickDetailKey'    
BEGIN    
   SET @c_SQL = ''    
   SET @c_ExecArguments = ''    
   SET @b_RecFound = 0    
    
   SET @c_SQL = N'SELECT TOP 1 @b_RecFound = 1 '    
               + 'FROM ' + ISNULL(RTRIM(@c_SourceDB),'') + '.dbo.PickDetail P WITH (NOLOCK) '    
               + 'JOIN ' + ISNULL(RTRIM(@c_TargetDB),'') + '.dbo.OrderDetail O WITH (NOLOCK) '    
               + 'ON (P.OrderKey = O.OrderKey) '    
               + 'WHERE P.PickDetailKey =  ISNULL(RTRIM(@c_DocKey),'')  '    
    
   SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50),@b_RecFound INT OUTPUT '    
    
   EXEC sp_ExecuteSql @c_SQL    
                    , @c_ExecArguments    
     , @c_DocKey     
                    , @b_RecFound OUTPUT    
    
   IF @b_RecFound = 0    
   BEGIN    
       SELECT @n_Continue = 3      
    SET @n_err = 700010    
       SELECT @c_errmsg = 'PickDetail Not Found. PickDetailKey = ' + ISNULL(RTRIM(@c_DocKey),'') + '. (isp_ReTriggerTransmitLog_MovePickDetail)'    
       GOTO QUIT    
   END    
END    
ELSE    
BEGIN    
   SET @c_SQL = ''    
   SET @c_ExecArguments = ''    
   SET @b_RecFound = 0    
   IF  not exists ( SELECT TOP 1 1 FROM PICKDETAIL PD WITH (NOLOCK)   
             JOIN ORDERDETAIL OD WITH (nolock) ON PD.OrderKey = OD.Orderkey WHERE PD.OrderKey = @c_DocKey)     
   BEGIN    
      SET @c_SQL = N'SELECT TOP 1 @b_RecFound = 1 '    
               + 'FROM ' + ISNULL(RTRIM(@c_SourceDB),'') + '.dbo.PickDetail P WITH (NOLOCK) '    
               + 'JOIN ' + ISNULL(RTRIM(@c_TargetDB),'') + '.dbo.OrderDetail O WITH (NOLOCK) '    
               + 'ON (P.OrderKey = O.OrderKey) '    
               + 'WHERE P.OrderKey =  ISNULL(RTRIM(@c_DocKey),'''') '    
    
      SET @c_ExecArguments = N'@c_DocKey NVARCHAR(50),@b_RecFound INT OUTPUT '    
    
      EXEC sp_ExecuteSql @c_SQL    
               , @c_ExecArguments    
               , @c_DocKey     
               , @b_RecFound OUTPUT    
    
      IF @b_RecFound = 0    
      BEGIN    
          SELECT @n_Continue = 3      
          SET @n_err = 700011    
          SELECT @c_errmsg = 'PickDetail Not Found. OrderKey = ' + ISNULL(RTRIM(@c_DocKey),'') + '. (isp_ReTriggerTransmitLog_MovePickDetail)'    
         GOTO QUIT    
      END    
  END    
END    
    
SET @c_SQL = ''    
IF @c_KeyColumn = 'PickDetailKey'    
BEGIN    
   SET @c_SQL = N'INSERT INTO #PD (StorerKey, Sku, Lot, Loc, Id) '    
               + 'SELECT P.StorerKey, P.Sku, P.Lot, P.Loc, P.Id '    
               + 'FROM ' + ISNULL(RTRIM(@c_SourceDB),'') + '.dbo.PickDetail P WITH (NOLOCK) '    
               + 'WHERE P.PickDetailKey = ISNULL(RTRIM(@c_DocKey),'''') '    
               + 'ORDER BY P.StorerKey, P.Sku, P.Lot, P.Loc, P.Id '    
END    
ELSE    
BEGIN    
   SET @c_SQL = N'INSERT INTO #PD (StorerKey, Sku, Lot, Loc, Id) '    
               + 'SELECT DISTINCT P.StorerKey, P.Sku, P.Lot, P.Loc, P.Id '    
               + 'FROM ' + ISNULL(RTRIM(@c_SourceDB),'') + '.dbo.PickDetail P WITH (NOLOCK) '    
               + 'WHERE P.OrderKey =  ISNULL(RTRIM(@c_DocKey),'''') '    
               + 'ORDER BY P.StorerKey, P.Sku, P.Lot, P.Loc, P.Id '    
END    
    
EXEC sp_ExecuteSql @c_SQL    
      , N'@c_DocKey NVARCHAR(50)'    
      ,  @c_DocKey     
    
IF EXISTS (SELECT 1 FROM #PD)    
BEGIN    
   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT StorerKey, Sku, Lot, Loc, Id    
      FROM #PD    
      ORDER BY StorerKey, Sku, Lot, Loc, Id    
    
   OPEN CUR1    
   FETCH NEXT FROM CUR1 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Loc, @c_Id    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      BEGIN TRAN    
    
      SET @c_PackKey = ''    
      SELECT @c_PackKey = PackKey    
      FROM SKU WITH (NOLOCK)    
      WHERE StorerKey = @c_StorerKey AND Sku = @c_Sku    
    
      IF @b_Debug = 1    
      BEGIN    
         SELECT @c_StorerKey '@c_StorerKey', @c_Sku '@c_Sku', @c_Lot '@c_Lot', @c_Loc '@c_Loc', @c_Id '@c_Id', @c_PackKey '@c_PackKey'    
      END    
    
      IF NOT EXISTS (SELECT 1 FROM LOTATTRIBUTE WITH (NOLOCK)    
                     WHERE Lot = @c_Lot)    
      BEGIN    
         IF @b_Debug = 1    
         BEGIN    
            select 'Insert LotAttribute:- ' + @c_Lot    
         END    
    
         EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'LotAttribute', 'Lot', @c_Lot, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug    
      END    
    
      IF NOT EXISTS (SELECT 1 FROM LOT WITH (NOLOCK)   
                     WHERE StorerKey = @c_StorerKey AND Sku = @c_Sku AND Lot = @c_Lot)    
      BEGIN    
         IF @b_Debug = 1    
         BEGIN    
            select 'Insert Lot:- ' + @c_Lot    
         END    
         BEGIN TRAN    
           INSERT INTO LOT (StorerKey, Sku, Qty, Lot, ArchiveCop)    
           VALUES (@c_StorerKey, @c_Sku, @n_DummyQty, @c_Lot, @c_ArchiveCop)    
         COMMIT TRAN    
   END    
    
      IF NOT EXISTS (SELECT 1 FROM ID WITH (NOLOCK)    
               WHERE Id = @c_Id)    
      BEGIN    
         IF @b_Debug = 1    
         BEGIN    
            select 'Insert Id:- ' + @c_Id    
         END    
         BEGIN TRAN    
           INSERT INTO ID (Id, Qty, Status, PackKey, ArchiveCop)    
           VALUES (@c_Id, @n_DummyQty, 'OK', @c_PackKey, @c_ArchiveCop)    
         COMMIT TRAN    
      END    
    
      IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)    
                     WHERE StorerKey = @c_StorerKey AND Sku = @c_Sku AND Lot = @c_Lot    
                     AND Loc = @c_Loc AND Id = @c_Id)    
      BEGIN    
         IF @b_Debug = 1    
         BEGIN    
            SELECT 'Insert LotxLocxId:- ' + @c_Lot + ' | ' + @c_Loc + ' | ' + @c_Id    
         END    
   BEGIN TRAN    
           INSERT INTO LOTxLOCxID (StorerKey, Sku, Qty, Lot, Loc, Id, ArchiveCop)    
           VALUES (@c_StorerKey, @c_Sku, @n_DummyQty, @c_Lot, @c_Loc, @c_Id, @c_ArchiveCop)    
         COMMIT TRAN    
      END    
    
      IF NOT EXISTS (SELECT 1 FROM SKUxLOC WITH (NOLOCK)    
                     WHERE StorerKey = @c_StorerKey AND Sku = @c_Sku AND Loc = @c_Loc)    
      BEGIN    
         IF @b_Debug = 1    
         BEGIN    
            SELECT 'Insert SkuxLoc:-' + @c_Sku + ' | ' + @c_Loc    
         END    
         BEGIN TRAN    
           INSERT INTO SKUxLOC (StorerKey, Sku, Qty, Loc, ArchiveCop)    
           VALUES (@c_StorerKey, @c_Sku, @n_DummyQty, @c_Loc, '9')    
         COMMIT TRAN  
         BEGIN TRAN  
            Update SKUxLOC    
             Set ArchiveCop = NULL, trafficCop = NULL    
             where StorerKey =  @c_StorerKey    
             and Sku = @c_Sku    
             and loc = @c_Loc    
    
         COMMIT TRAN    
      END    
    
      IF @@ERROR = 0    
      BEGIN    
         COMMIT TRAN    
         SET @c_ValidFlag = 'Y'    
      END    
      ELSE    
      BEGIN    
         ROLLBACK TRAN    
         SET @c_ValidFlag  = 'N'    
         GOTO QUIT    
      END    
    
      FETCH NEXT FROM CUR1 INTO @c_StorerKey, @c_Sku, @c_Lot, @c_Loc, @c_Id    
   END    
   CLOSE CUR1    
   DEALLOCATE CUR1    
    
   IF @b_Debug = 1    
   BEGIN    
       SELECT @n_Continue = 3      
       SELECT @c_errmsg = 'Inventory Created -> ' + @c_ValidFlag + ' (isp_ReTriggerTransmitLog_MovePickDetail)'    
   END    
    
   IF @c_ValidFlag = 'Y'    
   BEGIN    
       SET @c_SQL = ''    
       SET @c_SQL = N'INSERT INTO #ARPICKDET (Pickdetailkey,Orderkey) '    
               + 'SELECT DISTINCT P.Pickdetailkey,P.orderkey '    
               + 'FROM ' + ISNULL(RTRIM(@c_SourceDB),'') + '.dbo.PickDetail P WITH (NOLOCK) '    
               + 'WHERE P.OrderKey =  ISNULL(RTRIM(@c_DocKey),'''') '    
               + 'ORDER BY P.Pickdetailkey '    
       
       EXEC sp_ExecuteSql @c_SQL    
                  , N'@c_DocKey NVARCHAR(50)'    
                  ,  @c_DocKey     
   IF EXISTS (SELECT 1 FROM #ARPICKDET)    
   BEGIN    
      DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT Pickdetailkey    
      FROM #ARPICKDET WITH (NOLOCK)    
      WHERE Orderkey = @c_DocKey    
      ORDER BY Pickdetailkey    
    
   OPEN CUR_PICKDETAIL    
   FETCH NEXT FROM CUR_PICKDETAIL INTO @c_Pickdetailkey    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
    
    EXEC isp_ReTriggerTransmitLog_MoveData @c_SourceDB, @c_TargetDB, 'dbo', '%liateDkciP%', 'Pickdetailkey', @c_Pickdetailkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT, @b_Debug    
       
    FETCH NEXT FROM CUR_PICKDETAIL INTO @c_Pickdetailkey    
  END    
    CLOSE CUR_PICKDETAIL    
    DEALLOCATE CUR_PICKDETAIL    
    END    
   END    
END -- IF EXISTS    
    
IF ISNULL(OBJECT_ID('tempdb..#PD'),'') <> ''    
BEGIN    
   DROP TABLE #PD    
END    
    
QUIT:    
    
 IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_ReTriggerTransmitLog_MovePickDetail'    
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SET @b_success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    


GO