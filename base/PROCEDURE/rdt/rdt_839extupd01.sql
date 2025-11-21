SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_839ExtUpd01                                           */
/* Purpose: TM Replen From, Extended Update for KR                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2018-10-11   ChewKP    1.0   WMS-5156 Created                              */
/* 2019-09-10   YeeKung   1.1   WMS-10517 Add parms in gettask (yeekung01)    */
/* 2022-04-20   YeeKung   1.2   WMS-19311 Add Data capture (yeekung02)        */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_839ExtUpd01]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cPickZone       NVARCHAR( 10)
   ,@cDropID         NVARCHAR( 20)
   ,@cLOC            NVARCHAR( 10)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cOption         NVARCHAR( 1)
   ,@cLottableCode   NVARCHAR( 30)
   ,@cLottable01     NVARCHAR( 18)
   ,@cLottable02     NVARCHAR( 18)
   ,@cLottable03     NVARCHAR( 18)
   ,@dLottable04     DATETIME
   ,@dLottable05     DATETIME
   ,@cLottable06     NVARCHAR( 30)
   ,@cLottable07     NVARCHAR( 30)
   ,@cLottable08     NVARCHAR( 30)
   ,@cLottable09     NVARCHAR( 30)
   ,@cLottable10     NVARCHAR( 30)
   ,@cLottable11     NVARCHAR( 30)
   ,@cLottable12     NVARCHAR( 30)
   ,@dLottable13     DATETIME
   ,@dLottable14     DATETIME
   ,@dLottable15     DATETIME
   ,@cPackData1      NVARCHAR( 30)
   ,@cPackData2      NVARCHAR( 30)
   ,@cPackData3      NVARCHAR( 30) 
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT



   DECLARE @cFromID        NVARCHAR( 18)
   --DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cStatus        NVARCHAR( 10)
   DECLARE @cSerialNoKey   NVARCHAR( 10)
   DECLARE @cLoseID        NVARCHAR( 1)
          ,@cFromLoc       NVARCHAR( 10)
          ,@cType          NVARCHAR( 10)
          ,@cVNAMessage    NVARCHAR(MAX)
          ,@cDeviceID      NVARCHAR(10)
          --,@nInputKey      INT

          ,@cTruckType     NVARCHAR(10)

          ,@cPrevFromLoc   NVARCHAR(10)
          ,@cPrevTaskDetailKey NVARCHAR(10)
          ,@cSuggLOC       NVARCHAR(10)
          ,@cSKUDescr      NVARCHAR(60)
          ,@cDisableQTYField NVARCHAR(1)
          ,@nTtlBlncQty      INT -- (yeekung01)
          ,@nBlncQty         INT -- (yeekung01)


   SET @nTranCount = @@TRANCOUNT


   BEGIN TRAN
   SAVE TRAN rdt_839ExtUpd01

   SET @cType = 'VNA'
   SET @cTruckType = ''




   -- TM Replen From
   IF @nFunc = 839
   BEGIN
      --SELECT
      --      @cSKU = SKU,
      --      @cPickMethod = PickMethod,
      --      @cStorerKey = StorerKey,
      --      --@cFromID = FromID,
      --      --@cToID = ToID,
      --      @cToLOC = ToLOC,
      --      --@cStatus = Status
      --      @cFromLoc = FromLoc
      --FROM dbo.TaskDetail WITH (NOLOCK)
      --WHERE TaskdetailKey = @cTaskdetailKey

--      SELECT @cFacility = Facility
--      FROM dbo.Loc WITH (NOLOCK)
--      WHERE Loc = @cFromLoc

      SELECT @nInputKey = InputKey
            ,@cDeviceID = DeviceID
            ,@cOption   = I_Field01
      FROM rdt.RDTMobRec WITH (NOLOCK)
      WHERE Mobile = @nMobile
      AND Func = @nFunc

      SELECT @cTruckType = Short
      FROM dbo.Codelkup WITH (NOLOCK)
      WHERE ListName = 'DEVICETYP'
      AND StorerKey = @cStorerKey
      AND Code = @nFunc

      IF @nStep = 2 -- ToLOC
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF ISNULL(@cDeviceID,'') <> ''
            BEGIN
               IF ISNULL(@cTruckType ,'' ) = 'PL'
               BEGIN
                  SET @cVNAMessage = 'STXGETPL;'  + @cLOC + 'ETX'
               END
               ELSE IF ISNULL(@cTruckType,'') = 'CT'
               BEGIN
                  SET @cVNAMessage = 'STXGETCT;'  + @cLOC + 'ETX'
               END

               EXEC [RDT].[rdt_GenericSendMsg]
                   @nMobile      = @nMobile
                  ,@nFunc        = @nFunc
                  ,@cLangCode    = @cLangCode
                  ,@nStep        = @nStep
                  ,@nInputKey    = @nInputKey
                  ,@cFacility    = @cFacility
                  ,@cStorerKey   = @cStorerKey
                  ,@cType        = @cType
                  ,@cDeviceID    = @cDeviceID
                  ,@cMessage     = @cVNAMessage
                  ,@nErrNo       = @nErrNo       OUTPUT
                  ,@cErrMsg      = @cErrMsg      OUTPUT

               IF @nErrNo <> 0
                  GOTO RollBackTran

            END
         END
                     -- Full pallet single SKU
            --IF @cFromID <> '' AND @cPickMethod = 'FP' AND @cSKU <> ''
            --BEGIN
               -- Serial no
               --IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND SerialNoCapture = '1')
               --BEGIN
               --   -- Get LOC info
               --   SELECT @cLoseID = LoseID FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC

               --   -- ID changed
               --   IF @cLoseID = '1' OR @cFromID <> @cToID
               --   BEGIN
               --      -- Lose ID
               --      IF @cLoseID = '1'
               --         SET @cToID = ''

               --      BEGIN TRAN
               --      SAVE TRAN rdt_839ExtUpd01

               --      -- Loop serial no on ID
               --      DECLARE @curSNO CURSOR
               --      SET @curSNO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               --         SELECT SerialNoKey
               --         FROM dbo.SerialNo WITH (NOLOCK)
               --         WHERE StorerKey = @cStorerKey
               --            AND SKU = @cSKU
               --            AND ID = @cFromID
               --      OPEN @curSNO
               --      FETCH NEXT FROM @curSNO INTO @cSerialNoKey
               --      WHILE @@FETCH_STATUS = 0
               --      BEGIN
               --         -- Update SerialNo ID
               --         UPDATE dbo.SerialNo SET
               --            ID = @cToID,
               --            EditDate = GETDATE(),
               --            EditWho  = SUSER_SNAME(),
               --            Trafficcop = NULL
               --         WHERE SerialNoKey = @cSerialNoKey
               --         IF @@ERROR <> 0
               --         BEGIN
               --            SET @nErrNo = 116052
               --            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd SNO Fail
               --            GOTO RollBackTran
               --         END

               --         FETCH NEXT FROM @curSNO INTO @cSerialNoKey
               --      END

               --      COMMIT TRAN rdt_839ExtUpd01 -- Only commit change made here
               --   END
               --END
         --END
         --END
      END

      IF @nStep = 3 -- SKU
      BEGIN
         IF @nInputKey = 1
         BEGIN
            EXEC rdt.rdt_PickPiece_GetTask @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'NEXTLOC'
               ,@cPickSlipNo
               ,@cPickZone
               ,@nTtlBlncQty      OUTPUT  --(yeekung01)
               ,@nBlncQty         OUTPUT  --(yeekung01)
               ,4
               ,@cSuggLOC         OUTPUT
               ,@cSKU             OUTPUT
               ,@cSKUDescr        OUTPUT
               ,@nQty             OUTPUT
               ,@cDisableQTYField OUTPUT
               ,@cLottableCode    OUTPUT
               ,@cLottable01      OUTPUT, @cLottable02  OUTPUT, @cLottable03  OUTPUT, @dLottable04  OUTPUT, @dLottable05  OUTPUT
               ,@cLottable06      OUTPUT, @cLottable07  OUTPUT, @cLottable08  OUTPUT, @cLottable09  OUTPUT, @cLottable10  OUTPUT
               ,@cLottable11      OUTPUT, @cLottable12  OUTPUT, @dLottable13  OUTPUT, @dLottable14  OUTPUT, @dLottable15  OUTPUT
               ,@nErrNo           OUTPUT
               ,@cErrMsg          OUTPUT

            IF ISNULL(@cDeviceID,'') <> ''
            BEGIN
               IF ISNULL(@cTruckType ,'' ) = 'PL'
               BEGIN
                  SET @cVNAMessage = 'STXGETPL;'  + @cSuggLOC + 'ETX'
               END
               ELSE IF ISNULL(@cTruckType,'') = 'CT'
               BEGIN
                  SET @cVNAMessage = 'STXGETCT;'  + @cSuggLOC + 'ETX'
               END

               EXEC [RDT].[rdt_GenericSendMsg]
                   @nMobile      = @nMobile
                  ,@nFunc        = @nFunc
                  ,@cLangCode    = @cLangCode
                  ,@nStep        = @nStep
                  ,@nInputKey    = @nInputKey
                  ,@cFacility    = @cFacility
                  ,@cStorerKey   = @cStorerKey
                  ,@cType        = @cType
                  ,@cDeviceID    = @cDeviceID
                  ,@cMessage     = @cVNAMessage
                  ,@nErrNo       = @nErrNo       OUTPUT
                  ,@cErrMsg      = @cErrMsg      OUTPUT

               IF @nErrNo <> 0
                  GOTO RollBackTran

            END
         END
      END

--      IF @nStep = 5
--      BEGIN
--         IF @nInputKey = 1
--         BEGIN
--            IF ISNULL(@cDeviceID,'') <> ''
--            BEGIN
--
--
--               IF @cOption = '1'
--               BEGIN
--                  SELECT @cPrevTaskDetailKey = V_TaskDetailKey
--                  FROM rdt.rdtMobRec WITH (NOlOCK)
--                  WHERE Mobile = @nMobile
--
--                  --SELECT @cTaskDetailKey '@cTaskDetailKey' , @cPrevTaskDetailKey '@cPrevTaskDetailKey'
--
--                  SELECT @cPrevFromLoc = FromLoc
--                  FROM dbo.TaskDetail WITH (NOLOCK)
--                  WHERE TaskDetailKey = @cPrevTaskDetailKey
--
--                  IF ISNULL(@cPrevFromLoc,'') <> ISNULL(@cFromLoc ,'' )
--                  BEGIN
--                     IF ISNULL(@cTruckType ,'' ) = 'PL'
--                     BEGIN
--                        SET @cVNAMessage = 'STXGETPL;'  + @cFromLoc + 'ETX'
--                     END
--                     ELSE IF ISNULL(@cTruckType,'') = 'CT'
--                     BEGIN
--                        SET @cVNAMessage = 'STXGETCT;'  + @cFromLoc + 'ETX'
--                     END
--
--                     EXEC [RDT].[rdt_GenericSendMsg]
--                         @nMobile      = @nMobile
--                        ,@nFunc        = @nFunc
--                        ,@cLangCode    = @cLangCode
--                        ,@nStep        = @nStep
--                        ,@nInputKey    = @nInputKey
--                        ,@cFacility    = @cFacility
--                        ,@cStorerKey   = @cStorerKey
--                        ,@cType        = @cType
--                        ,@cDeviceID    = @cDeviceID
--                        ,@cMessage     = @cVNAMessage
--                        ,@nErrNo       = @nErrNo       OUTPUT
--                        ,@cErrMsg      = @cErrMsg      OUTPUT
--
--                     IF @nErrNo <> 0
--                        GOTO RollBackTran
--                  ENd
--               END
--
--               IF @cOption = '9'
--               BEGIN
--
--                  IF ISNULL(@cTruckType ,'' ) = 'PL'
--                  BEGIN
--                     SET @cVNAMessage = 'STXPUTPL;'  + @cToLOC + 'ETX'
--                  END
--                  ELSE IF ISNULL(@cTruckType,'') = 'CT'
--                  BEGIN
--                     SET @cVNAMessage = 'STXPUTCT;'  + @cToLOC + 'ETX'
--                  END
--
--                  EXEC [RDT].[rdt_GenericSendMsg]
--                      @nMobile      = @nMobile
--                     ,@nFunc        = @nFunc
--                     ,@cLangCode    = @cLangCode
--                     ,@nStep        = @nStep
--                     ,@nInputKey    = @nInputKey
--                     ,@cFacility    = @cFacility
--                     ,@cStorerKey   = @cStorerKey
--                     ,@cType        = @cType
--                     ,@cDeviceID    = @cDeviceID
--                     ,@cMessage     = @cVNAMessage
--                     ,@nErrNo       = @nErrNo       OUTPUT
--                     ,@cErrMsg      = @cErrMsg      OUTPUT
--
--                  IF @nErrNo <> 0
--                     GOTO RollBackTran
--               END
--            END
--
--         END
--      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_839ExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO