SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdt_TM_CycleCount_InsertCCDetail                         */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose:                                                                  */
/*          Called By TM CycleCount                                          */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2011-11-17 1.0  ChewKP   SOS#227151 Created                               */
/* 2013-10-25 1.1  James    Buf fix (james01)                                */
/* 2023-10-20 1.2  James    WMS-23249 Add default value for AdjType and      */
/*                          AdjReasonCode (james02)                          */
/*****************************************************************************/
CREATE   PROC [RDT].[rdt_TM_CycleCount_InsertCCDetail] (
      @nMobile          INT
     ,@c_TaskDetailKey   NVARCHAR(10)
     ,@nErrNo           INT OUTPUT
     ,@cErrMsg          NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
     ,@cLangCode        NVARCHAR(3)
     ,@c_StorerKey      NVARCHAR(20)
     ,@c_Loc            NVARCHAR(10)
     ,@c_Facility       NVARCHAR(5)
     ,@c_SKU            NVARCHAR(20) = ''
     ,@c_PickMethod     NVARCHAR(10)
     ,@c_CCOptions      NVARCHAR(1)
     ,@c_SourceKey      NVARCHAR(30)
)
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @b_success             INT
          , @n_err                 INT
          , @c_errmsg              NVARCHAR(250)
          , @nTranCount            INT

   DECLARE @c_lot          NVARCHAR(10),
      @c_id                NVARCHAR(18),
      @c_Lottable01        NVARCHAR(18),
      @c_Lottable02        NVARCHAR(18),
      @c_Lottable03        NVARCHAR(18),
      @d_Lottable04        datetime,
      @d_Lottable05        datetime,
      @n_qty               int,
      @c_Aisle             NVARCHAR(10),
      @n_LocLevel          int,
      @c_prev_Facility     NVARCHAR(5),
      @c_prev_Aisle        NVARCHAR(10),
      @n_prev_LocLevel     int,
      @c_ccdetailkey       NVARCHAR(10),
      @c_ccsheetno         NVARCHAR(10),
      @n_LineCount         int,
      @c_PreLogLocation    NVARCHAR(18),
      @c_CCLogicalLoc      NVARCHAR(18),
      @n_SystemQty         int,
      @c_PrevZone          NVARCHAR(10),
      @c_PutawayZone       NVARCHAR(10),
      @c_CCKEy             NVARCHAR(10),
      @n_LinesPerPage      int,
      @c_CCSheetNoKeyName  NVARCHAR(30),
      @c_AdjType           NVARCHAR(10),
      @c_AdjReasonCode     NVARCHAR(3),
      @n_Func              INT

   SET @nTranCount         = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN TM_CC

   IF @c_StorerKey = ''
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.stocktakesheetparameters WITH (NOLOCK)
                      WHERE StockTakeKey = @c_SourceKey)
      BEGIN
         INSERT INTO stocktakesheetparameters (stocktakekey, Facility,storerKey,ExcludeQtyPicked)
         VALUES (@c_SourceKey, @c_Facility, 'ALL', 'Y' )
      END
   END
   ELSE
   BEGIN
      SELECT @n_Func = Func
      FROM rdt.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      SET @c_AdjReasonCode = rdt.RDTGetConfig( @n_Func, 'TMCC_AdjReasonCode', @c_StorerKey)
      IF @c_AdjReasonCode IN ('0', '')
         SET @c_AdjReasonCode = ''

      SET @c_AdjType = rdt.RDTGetConfig( @n_Func, 'TMCC_AdjType', @c_StorerKey)
      IF @c_AdjType IN ('0', '')
         SET @c_AdjType = ''

      IF NOT EXISTS ( SELECT 1 FROM dbo.stocktakesheetparameters WITH (NOLOCK)
                      WHERE StockTakeKey = @c_SourceKey )
      BEGIN
         INSERT INTO stocktakesheetparameters (stocktakekey, Facility,storerKey ,ExcludeQtyPicked, AdjReasonCode, AdjType)
         VALUES (@c_SourceKey, @c_Facility, @c_StorerKey, 'Y', @c_AdjReasonCode, @c_AdjType )
      END
   END

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 76403
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'InsCCParmFail'
      GOTO RollBackTran
   END

   SET @c_CCKEy = @c_SourceKey

   -- DELETE PREVIOUSLY GENERATE CCDetail
   IF EXISTS (SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
              WHERE CCKey = @c_SourceKey
              AND Loc = @c_Loc)
   BEGIN
      GOTO QUIT
   END

   IF @c_CCOptions IN ('1','2','3')
   BEGIN
      IF @c_PickMethod = 'LOC'
      BEGIN
         IF @c_CCOptions = 1 -- 1 = UCC count; if gen count sheet with ucc (james01)
            EXEC ispRDTGenCountSheetByUCC @c_SourceKey , @c_Loc , '', @c_TaskDetailKey
         ELSE
            EXEC ispRDTGenCountSheet @c_SourceKey , @c_Loc , '', @c_TaskDetailKey
      END

      IF @c_PickMethod = 'SKU'
      BEGIN
	           SET @nErrNo = 76403
         SET @cErrMsg = 'DENNISTEST'+rdt.RDTGetConfig( @n_Func, 'ExtendedGenCountSheetSP', @c_StorerKey) --'InsCCParmFail'
         EXEC ispRDTGenCountSheet @c_SourceKey , @c_Loc , @c_SKU, @c_TaskDetailKey
      END
   END
   GOTO QUIT

   RollBackTran:
   ROLLBACK TRAN TM_CC

   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN TM_CC

END -- Procedure

GO