SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_839ExtInfo12                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 09-12-2022  1.0  Ung         WMS-21244 Created                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_839ExtInfo12]
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,       
   @nAfterStep   INT,    
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5) , 
   @cStorerKey   NVARCHAR( 15), 
   @cType        NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cPickZone    NVARCHAR( 10), --(yeekun01) 
   @cDropID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,           
   @nActQty      INT,
   @nSuggQTY     INT,
   @cExtendedInfo NVARCHAR(20) OUTPUT, 
   @nErrNo       INT           OUTPUT, 
   @cErrMsg      NVARCHAR(250) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey NVARCHAR( 10)
   DECLARE @cConsigneeKey NVARCHAR( 15)
   DECLARE @cSUSR5 NVARCHAR( 20)

   IF @nFunc = 839 -- Pick piece
   BEGIN
      IF @nAfterStep = 1 -- PickSlip
      BEGIN
         -- Remove own locking
         IF EXISTS( SELECT TOP 1 1 FROM rdt.rdtPickPieceLock WITH (NOLOCK) WHERE LockWho = SUSER_SNAME())
         BEGIN
            DECLARE @nRowRef INT
            DECLARE @curLock CURSOR
            SET @curLock = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT RowRef 
               FROM rdt.rdtPickPieceLock WITH (NOLOCK)
               WHERE LockWho = SUSER_SNAME()
            OPEN @curLock
            FETCH NEXT FROM @curLock INTO @nRowRef
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE rdt.rdtPickPieceLock SET
                  LockWho = '', 
                  LockDate = NULL
               WHERE RowRef = @nRowRef
               FETCH NEXT FROM @curLock INTO @nRowRef
            END
            
            -- Remove all if nobody locking
            IF NOT EXISTS( SELECT TOP 1 1 FROM rdt.rdtPickPieceLock WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LockWho <> '')
            BEGIN
               SET @curLock = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT RowRef 
                  FROM rdt.rdtPickPieceLock WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
               OPEN @curLock
               FETCH NEXT FROM @curLock INTO @nRowRef
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  DELETE rdt.rdtPickPieceLock 
                  WHERE RowRef = @nRowRef
                  FETCH NEXT FROM @curLock INTO @nRowRef
               END
            END
         END
      END
   END

Quit:

END

GO