SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_803AsignExtUpd02                                      */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 25-07-2021 1.0  yeekung  WMS-17122 Created                                 */
/******************************************************************************/
CREATE PROC [RDT].[rdt_803AsignExtUpd02] (
   @nMobile     INT,           
   @nFunc       INT,           
   @cLangCode   NVARCHAR( 3),  
   @nStep       INT,           
   @nInputKey   INT,           
   @cFacility   NVARCHAR( 5) , 
   @cStorerKey  NVARCHAR( 10), 
   @cStation    NVARCHAR( 10),  
   @cMethod     NVARCHAR( 15), 
   @cCurrentSP  NVARCHAR( 60), 
   @tVar        VariableTable READONLY, 
   @nErrNo      INT           OUTPUT,  
   @cErrMsg     NVARCHAR(250) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cBatchkey NVARCHAR(20),
           @cDevicePos nvarchar(100),
           @cType NVARCHAR(20),
           @cDeviceStatus NVARCHAR(1),
           @cBusr9  NVARCHAR(20)


   IF @cCurrentSP = 'rdt_PTLPiece_Assign_Batch'
   BEGIN
      -- Parameter mapping
      SELECT @cBatchkey = Value FROM @tVar WHERE Variable = '@cBatchKey'

      SELECT @cType = Value FROM @tVar WHERE Variable = '@cType'

      
      IF @cType='CHECK'
      BEGIN
         IF EXISTS(SELECT 1
            FROM codelkup (NOLOCK)
            WHERE listname='CHKPICK'
            AND storerkey=@cStorerKey
            AND code=@nFunc
            AND long='SKU.BUSR9'
            AND ISNULL(short,'') NOT IN ('ALL',''))
         BEGIN

            IF EXISTS (SELECT 1 FROM pickdetail pd(NOLOCK)
                           JOIN sku s (NOLOCK) ON pd.sku=s.sku AND pd.Storerkey=s.StorerKey
                           WHERE PickSlipNo=@cBatchkey
                           AND s.storerkey=@cStorerKey
                           AND s.BUSR9 IN (SELECT short
                                          FROM codelkup (NOLOCK)
                                          WHERE listname='CHKPICK'
                                          AND storerkey=@cStorerKey
                                          AND code=@nFunc
                                          AND long='SKU.BUSR9'))
            BEGIN
               -- Check pick not completed
               IF rdt.RDTGetConfig( @nFunc, 'CheckPickCompleted', @cStorerKey) = '2'
               BEGIN
                  IF EXISTS( SELECT 1 
                     FROM PackTask T WITH (NOLOCK) 
                        JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = T.OrderKey)
                        JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                     WHERE T.TaskBatchNo = @cBatchkey
                        AND PD.Status IN ('0','4')
                        AND PD.QTY > 0)
                  BEGIN
                     SET @nErrNo = 99705
                     SET @cErrMsg =rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick NotFinish
                     GOTO Quit
                  END     
                  
               END
            END
         END
         ELSE IF EXISTS (SELECT 1
            FROM codelkup (NOLOCK)
            WHERE listname='CHKPICK'
            AND storerkey=@cStorerKey
            AND code=@nFunc
            AND long='SKU.BUSR9'
            AND ISNULL(short,'') IN ('ALL'))
         BEGIN
              -- Check pick not completed
            IF rdt.RDTGetConfig( @nFunc, 'CheckPickCompleted', @cStorerKey) = '2'
            BEGIN
               IF EXISTS( SELECT 1 
                  FROM PackTask T WITH (NOLOCK) 
                     JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = T.OrderKey)
                     JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  WHERE T.TaskBatchNo = @cBatchkey
                     AND PD.Status IN ('0')
                     AND PD.QTY > 0)
               BEGIN
                  SET @nErrNo = 99705
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pick NotFinish
                  GOTO Quit
               END         
            END
         END
      

      END
   END

Quit:

END

GO