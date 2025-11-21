SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: [rdt_830InfoVLT]                                    */
/* Copyright: Maersk                                                    */
/*                                                                      */
/* Purpose: Nullyfies c_string30 to avoid not providing pick zone       */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-06-05 1.0  PPA374                                               */
/************************************************************************/

CREATE   PROC [RDT].[rdt_830InfoVLT] (
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
            @cSuggLOC NVARCHAR( 10),  
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
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   IF (@nStep = 2 AND @nInputKey = 0)
   BEGIN
      UPDATE rdt.RDTMOBREC WITH(ROWLOCK)
      SET 
         C_String30 = '', 
         I_Field05 = '', 
         O_Field05 ='', 
         V_String35='', 
         C_String29 = '1'
      WHERE Mobile = @nMobile
   END

   IF @nStep IN (2,4)
   BEGIN
      IF EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE loc = @cLOC AND
         (PutawayZone IN 
         (SELECT code FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'VNAZONHUSQ')
         OR 
         PutawayZone IN 
         (SELECT code FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'WAZONEHUSQ'))
      )
      BEGIN
         SET @cExtendedInfo = 'Scan LPN or SKU'
      END
      ELSE
      BEGIN
         SET @cExtendedInfo = 'Scan SKU to proceed'
      END

   END
END

GO