SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_MovePickDetail                                  */
/* Creation Date:                                                       */
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
/* 01-Dec-2017  Leong     1.0   Verify OrderDetail vs PickDetail.       */
/* 24-Jan-2018  Leong     1.0   For Pickdetail record only.             */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_MovePickDetail]
     @c_SourceDB    NVARCHAR(30)
   , @c_TargetDB    NVARCHAR(30)
   , @c_KeyColumn   NVARCHAR(50) -- PickDetailKey / OrderKey
   , @c_DocKey      NVARCHAR(50)
   , @b_Debug       INT = 0
AS
   SET NOCOUNT ON
   SET ANSI_NULLS ON
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

CREATE TABLE #PD (
     StorerKey NVARCHAR(15) NULL
   , Sku       NVARCHAR(20) NULL
   , Lot       NVARCHAR(10) NULL
   , Loc       NVARCHAR(10) NULL
   , Id        NVARCHAR(18) NULL
   )

IF ISNULL(RTRIM(@c_KeyColumn),'') NOT IN ('PickDetailKey','OrderKey')
BEGIN
   PRINT ''
   PRINT '-------------------------------------------------'
   PRINT 'Invalid Table Key Column: ' + ISNULL(RTRIM(@c_KeyColumn),'') + '. (isp_MovePickDetail)'
   PRINT '-------------------------------------------------'
   PRINT ''

   GOTO QUIT
END

IF @c_KeyColumn = 'PickDetailKey'
BEGIN
   SET @c_SQL = ''
   SET @c_ExecArguments = ''
   SET @b_RecFound = 0

   SET @c_SQL = N'SELECT @b_RecFound = 1 '
               + 'FROM ' + ISNULL(RTRIM(@c_SourceDB),'') + '.dbo.PickDetail P WITH (NOLOCK) '
               + 'JOIN ' + ISNULL(RTRIM(@c_TargetDB),'') + '.dbo.OrderDetail O WITH (NOLOCK) '
               + 'ON (P.OrderKey = O.OrderKey) '
               + 'WHERE P.PickDetailKey = ''' + ISNULL(RTRIM(@c_DocKey),'') + ''' '

   SET @c_ExecArguments = N'@b_RecFound INT OUTPUT '

   EXEC sp_ExecuteSql @c_SQL
                    , @c_ExecArguments
                    , @b_RecFound OUTPUT

   IF @b_RecFound = 0
   BEGIN
      PRINT ''
      PRINT '-------------------------------------------------'
      PRINT 'Orders / OrderDetail Not Found. PickDetailKey = ' + ISNULL(RTRIM(@c_DocKey),'') + '. (isp_MovePickDetail)'
      PRINT '-------------------------------------------------'
      PRINT ''

      GOTO QUIT
   END
END
ELSE
BEGIN
   SET @c_SQL = ''
   SET @c_ExecArguments = ''
   SET @b_RecFound = 0

   SET @c_SQL = N'SELECT @b_RecFound = 1 '
               + 'FROM ' + ISNULL(RTRIM(@c_SourceDB),'') + '.dbo.PickDetail P WITH (NOLOCK) '
               + 'JOIN ' + ISNULL(RTRIM(@c_TargetDB),'') + '.dbo.OrderDetail O WITH (NOLOCK) '
               + 'ON (P.OrderKey = O.OrderKey) '
               + 'WHERE P.OrderKey = ''' + ISNULL(RTRIM(@c_DocKey),'') + ''' '

   SET @c_ExecArguments = N'@b_RecFound INT OUTPUT '

   EXEC sp_ExecuteSql @c_SQL
                    , @c_ExecArguments
                    , @b_RecFound OUTPUT

   IF @b_RecFound = 0
   BEGIN
      PRINT ''
      PRINT '-------------------------------------------------'
      PRINT 'Orders / OrderDetail Not Found. OrderKey = ' + ISNULL(RTRIM(@c_DocKey),'') + '. (isp_MovePickDetail)'
      PRINT '-------------------------------------------------'
      PRINT ''

      GOTO QUIT
   END
END

SET @c_SQL = ''
IF @c_KeyColumn = 'PickDetailKey'
BEGIN
   SET @c_SQL = N'INSERT INTO #PD (StorerKey, Sku, Lot, Loc, Id) '
               + 'SELECT DISTINCT P.StorerKey, P.Sku, P.Lot, P.Loc, P.Id '
               + 'FROM ' + ISNULL(RTRIM(@c_SourceDB),'') + '.dbo.PickDetail P WITH (NOLOCK) '
               + 'WHERE P.PickDetailKey = ''' + ISNULL(RTRIM(@c_DocKey),'') + ''' '
               + 'ORDER BY P.StorerKey, P.Sku, P.Lot, P.Loc, P.Id '
END
ELSE
BEGIN
   SET @c_SQL = N'INSERT INTO #PD (StorerKey, Sku, Lot, Loc, Id) '
               + 'SELECT DISTINCT P.StorerKey, P.Sku, P.Lot, P.Loc, P.Id '
               + 'FROM ' + ISNULL(RTRIM(@c_SourceDB),'') + '.dbo.PickDetail P WITH (NOLOCK) '
               + 'WHERE P.OrderKey = ''' + ISNULL(RTRIM(@c_DocKey),'') + ''' '
               + 'ORDER BY P.StorerKey, P.Sku, P.Lot, P.Loc, P.Id '
END

EXEC sp_ExecuteSql @c_SQL

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
            PRINT 'Insert LotAttribute:- ' + @c_Lot
         END

         EXEC isp_MoveData @c_SourceDB, @c_TargetDB, 'dbo', 'LotAttribute', 'Lot', @c_Lot, @b_Debug
      END

      IF NOT EXISTS (SELECT 1 FROM LOT WITH (NOLOCK)
                     WHERE StorerKey = @c_StorerKey AND Sku = @c_Sku AND Lot = @c_Lot)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT 'Insert Lot:- ' + @c_Lot
         END

         INSERT INTO LOT (StorerKey, Sku, Qty, Lot, ArchiveCop)
         VALUES (@c_StorerKey, @c_Sku, @n_DummyQty, @c_Lot, @c_ArchiveCop)
      END

      IF NOT EXISTS (SELECT 1 FROM ID WITH (NOLOCK)
                     WHERE Id = @c_Id)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT 'Insert Id:- ' + @c_Id
         END

         INSERT INTO ID (Id, Qty, Status, PackKey, ArchiveCop)
         VALUES (@c_Id, @n_DummyQty, 'OK', @c_PackKey, @c_ArchiveCop)
      END

      IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
                     WHERE StorerKey = @c_StorerKey AND Sku = @c_Sku AND Lot = @c_Lot
                     AND Loc = @c_Loc AND Id = @c_Id)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT 'Insert LotxLocxId:- ' + @c_Lot + ' | ' + @c_Loc + ' | ' + @c_Id
         END

         INSERT INTO LOTxLOCxID (StorerKey, Sku, Qty, Lot, Loc, Id, ArchiveCop)
         VALUES (@c_StorerKey, @c_Sku, @n_DummyQty, @c_Lot, @c_Loc, @c_Id, @c_ArchiveCop)
      END

      IF NOT EXISTS (SELECT 1 FROM SKUxLOC WITH (NOLOCK)
                     WHERE StorerKey = @c_StorerKey AND Sku = @c_Sku AND Loc = @c_Loc)
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT 'Insert SkuxLoc:-' + @c_Sku + ' | ' + @c_Loc
         END

         INSERT INTO SKUxLOC (StorerKey, Sku, Qty, Loc, ArchiveCop)
         VALUES (@c_StorerKey, @c_Sku, @n_DummyQty, @c_Loc, @c_ArchiveCop)
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
      PRINT ''
      PRINT '-------------------------------------------------'
      PRINT 'Inventory Created -> ' + @c_ValidFlag + ' (isp_MovePickDetail)'
      PRINT '-------------------------------------------------'
      PRINT ''
   END

   IF @c_ValidFlag = 'Y'
   BEGIN
      EXEC isp_MoveData @c_SourceDB, @c_TargetDB, 'dbo', '%liateDkciP%', @c_KeyColumn, @c_DocKey, @b_Debug
   END
END -- IF EXISTS

IF ISNULL(OBJECT_ID('tempdb..#PD'),'') <> ''
BEGIN
   DROP TABLE #PD
END

QUIT:

GO