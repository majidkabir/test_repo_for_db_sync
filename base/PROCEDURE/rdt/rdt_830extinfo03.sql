SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_830ExtInfo03                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 09-11-2022  1.0  Ung         WMS-21032 Created                       */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_830ExtInfo03]
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cSuggLOC      NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cDropID       NVARCHAR( 20),
   @cSKU          NVARCHAR( 20),
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @nTaskQTY      INT,
   @nQTY          INT,
   @cToLOC        NVARCHAR( 10),
   @cOption       NVARCHAR( 1),
   @cExtendedInfo NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey NVARCHAR( 10)
   DECLARE @cConsigneeKey NVARCHAR( 15)
   DECLARE @cSUSR5 NVARCHAR( 20)

   IF @nFunc = 830 -- PickSKU
   BEGIN
      IF @nAfterStep = 1 -- PickSlip
      BEGIN
         -- Remove own locking
         IF EXISTS( SELECT TOP 1 1 FROM rdt.rdtPickSKULock WITH (NOLOCK) WHERE LockWho = SUSER_SNAME())
         BEGIN
            DECLARE @nRowRef INT
            DECLARE @curLock CURSOR
            SET @curLock = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT RowRef 
               FROM rdt.rdtPickSKULock WITH (NOLOCK)
               WHERE LockWho = SUSER_SNAME()
            OPEN @curLock
            FETCH NEXT FROM @curLock INTO @nRowRef
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE rdt.rdtPickSKULock SET
                  LockWho = '', 
                  LockDate = NULL
               WHERE RowRef = @nRowRef
               FETCH NEXT FROM @curLock INTO @nRowRef
            END

            -- Remove all if nobody locking
            IF NOT EXISTS( SELECT TOP 1 1 FROM rdt.rdtPickSKULock WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LockWho <> '')
            BEGIN
               SET @curLock = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT RowRef 
                  FROM rdt.rdtPickSKULock WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
               OPEN @curLock
               FETCH NEXT FROM @curLock INTO @nRowRef
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  DELETE rdt.rdtPickSKULock 
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