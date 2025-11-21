SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: rdt_839ExtUpd07                                           */
/* Copyright      : Maersk                                                    */ 
/* Purpose:Extended Puma                                                      */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2024-07-16   JHU151    1.0   FCR-428 Created                               */
/******************************************************************************/

CREATE       PROCEDURE [RDT].[rdt_839ExtUpd07]
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

   DECLARE @bSuccess INT   
   DECLARE @nExists  INT
   DECLARE @cShort   NVARCHAR(20)


   SET @nErrNo          = 0
   SET @cErrMSG         = ''


   IF @nFunc = 839
   BEGIN
      IF @nStep = 5
      BEGIN
         -- Short pick
         IF @nInputKey = 1
         BEGIN
            DECLARE
               @cStoredProcedure  NVARCHAR(50),
               @cCCTaskType       NVARCHAR(60),
               @cHoldType         NVARCHAR(60),
               @cSQL              NVARCHAR( MAX),
               @cSQLParam         NVARCHAR( MAX),
               @cLot              NVARCHAR(10),
               @cID               NVARCHAR(20),
               @cReasonCode       NVARCHAR(20),
               @b_Success         INT,
               @n_err             INT,
               @cPickDetailKey    NVARCHAR(50) = '',
               @cOrderKey         NVARCHAR(10) = '',
               @cLoadKey          NVARCHAR(10) = '',
               @cZone             NVARCHAR(18) = '',
               @c_errmsg          NVARCHAR(250)

            -- Short
            IF @cOption = '1'
            BEGIN
               SELECT 
                  @cReasonCode = code2,
                  @cCCTaskType = UDF01,-- CC task type
                  @cHoldType = UDF02 -- Hold type
               FROM codelkup 
               WHERE listname = 'RDTREASON'
               AND code = @nFunc
               AND storerkey = @cStorerKey

               SET @cStoredProcedure = rdt.rdtGetConfig( @nFunc, 'ActRDTreason', @cStorerKey)
               IF @cStoredProcedure = '0'
                  SET @cStoredProcedure = ''

               IF @cStoredProcedure <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cStoredProcedure AND type = 'P')
                  BEGIN
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cStoredProcedure) +
                           ' @nMobile, @nFunc, @cStorerKey, ' +
                           ' @cSKU, @cLOC, @cLot, @cID, @cReasonCode, ' +                      
                           ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                     SET @cSQLParam =
                           ' @nMobile         INT                      ' +
                           ',@nFunc           INT                      ' +
                           ',@cStorerKey      NVARCHAR( 15)            ' +
                           ',@cSKU            NVARCHAR( 20)            ' +
                           ',@cLOC            NVARCHAR( 10)            ' +
                           ',@cLot            NVARCHAR( 10)            ' +
                           ',@cID             NVARCHAR( 20)            ' +
                           ',@cReasonCode     NVARCHAR( 20)            ' +   
                           ',@nErrNo          INT           OUTPUT     ' +
                           ',@cErrMsg         NVARCHAR(250) OUTPUT  '

                     SELECT TOP 1
                           @cOrderKey = OrderKey,
                           @cLoadKey = ExternOrderKey,
                           @cZone = Zone
                     FROM dbo.PickHeader WITH (NOLOCK)
                     WHERE PickHeaderKey = @cPickSlipNo

                     WHILE (1=1)
                     BEGIN
                        -- Cross dock PickSlip
                        IF @cZone IN ('XD', 'LB', 'LP')
                        BEGIN
                           SELECT TOP 1
                              @cPickDetailKey = PD.PickDetailKey,
                              @cLot = Lot,
                              @cID = ID
                           FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                              JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                           WHERE RKL.PickSlipNo = @cPickSlipNo
                              AND PD.LOC = @cLOC
                              AND PD.SKU = @cSKU
                              AND (ISNULL(@cID,'') = '' OR ID = @cID)
                              AND PD.QTY > 0
                              AND (
                                    (@nFunc = 839  AND PD.status = '4')
                                    OR 
                                    (@nFunc = 957 AND PD.Status <> '4' AND PD.Status < '5')
                                    )
                              AND PD.PickDetailKey > @cPickDetailKey
                           ORDER BY PD.PickDetailKey
                        END
                        ELSE IF @cOrderKey <> ''
                        BEGIN
                           SELECT TOP 1
                              @cPickDetailKey = PD.PickDetailKey,
                              @cLot = Lot,
                              @cID = ID
                           FROM dbo.PickDetail PD WITH (NOLOCK)
                              JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
                           WHERE PD.OrderKey = @cOrderKey
                              AND PD.LOC = @cLOC
                              AND PD.SKU = @cSKU
                              AND (ISNULL(@cID,'') = '' OR ID = @cID)
                              AND PD.QTY > 0
                              AND (
                                    (@nFunc = 839  AND PD.status = '4')
                                    OR 
                                    (@nFunc = 957 AND PD.Status <> '4' AND PD.Status < '5')
                                    )
                              AND PD.PickDetailKey > @cPickDetailKey
                           ORDER BY PD.PickDetailKey
                        END
                        ELSE IF @cLoadKey <> ''
                        BEGIN
                           
                           SELECT TOP 1
                                 @cPickDetailKey = PD.PickDetailKey,
                                 @cLot = Lot,
                                 @cID = ID
                           FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                              JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                              JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
                           WHERE LPD.LoadKey = @cLoadKey
                              AND PD.LOC = @cLOC
                              AND PD.SKU = @cSKU
                              AND (ISNULL(@cID,'') = '' OR ID = @cID)
                              AND PD.QTY > 0
                              AND (
                                 (@nFunc = 839  AND PD.status = '4')
                                 OR 
                                 (@nFunc = 957 AND PD.Status <> '4' AND PD.Status < '5')
                                 )
                              AND PD.PickDetailKey > @cPickDetailKey
                           ORDER BY PD.PickDetailKey
                        END
                        ELSE
                        BEGIN
                           SELECT TOP 1
                                 @cPickDetailKey = PD.PickDetailKey,
                                 @cLot = Lot,
                                 @cID = ID
                           FROM dbo.PickDetail PD WITH (NOLOCK)
                           JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
                           WHERE PD.PickSlipNo = @cPickSlipNo
                           AND PD.LOC = @cLOC
                           AND PD.SKU = @cSKU
                           AND (ISNULL(@cID,'') = '' OR ID = @cID)
                              AND PD.QTY > 0
                              AND (
                                 (@nFunc = 839  AND PD.status = '4')
                                 OR 
                                 (@nFunc = 957 AND PD.Status <> '4' AND PD.Status < '5')
                                 )
                              AND PD.PickDetailKey > @cPickDetailKey
                           ORDER BY PD.PickDetailKey
                        END


                        IF @@ROWCOUNT = 0
                        BEGIN
                           BREAK
                        END
                        
                        EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                              @nMobile, @nFunc, @cStorerKey,
                              @cSKU, @cLOC, @cLot, @cID, @cReasonCode,
                              @nErrNo OUTPUT, @cErrMsg OUTPUT

                        IF @nErrNo <> 0
                              GOTO Quit

                     END
                  END
               END
            END
         END
      END
   END
Quit:


END
 

GO