SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_LottableField_Setfocus                          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Determine which lottable field should set focus.            */
/*          the 1st enable & blank lottable field will get focus        */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 25-Mar-2014 1.0  James       Created                                 */
/* 03-Jun-2014 1.1  James       Ignore lottable05. The value will auto  */
/*                              populate if field is enabled (james01)  */
/************************************************************************/

CREATE PROC [RDT].[rdt_LottableField_Setfocus] (
   @nMobile       INT,
   @c_LotLabel01  NVARCHAR(20),
   @c_LotLabel02  NVARCHAR(20),
   @c_LotLabel03  NVARCHAR(20),
   @c_LotLabel04  NVARCHAR(20),
   @c_LotLabel05  NVARCHAR(20),
   @c_Lottable01  NVARCHAR(18),
   @c_Lottable02  NVARCHAR(18),
   @c_Lottable03  NVARCHAR(18),
   @c_Lottable04  NVARCHAR(16),
   @c_Lottable05  NVARCHAR(16) 
   )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nLot01Blank INT, 
           @nLot02Blank INT, 
           @nLot03Blank INT, 
           @nLot04Blank INT, 
           @nLot05Blank INT, 
           @nFunc       INT, 
           @nErrNo     INT, 
           @cStorer     NVARCHAR( 15), 
           @cExtendedSetFocusSP     NVARCHAR( 20), 
           @cSQL        NVARCHAR( 1000), 
           @cSQLParam   NVARCHAR( 1000), 
           @cErrMsg    NVARCHAR( 20)  

   SELECT @nFunc = Func, @cStorer = StorerKey FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
   
   SET @cExtendedSetFocusSP = rdt.RDTGetConfig( @nFunc, 'ExtendedSetFocus', @cStorer)    
   IF @cExtendedSetFocusSP NOT IN ('0', '')
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedSetFocusSP AND type = 'P')    
      BEGIN    
         SET @nErrNo = 0
             
         SET @cSQL = 'EXEC ' + RTRIM( @cExtendedSetFocusSP) +     
            ' @n_Mobile, @c_LotLabel01, @c_LotLabel02, @c_LotLabel03, @c_LotLabel04, @c_LotLabel05, 
              @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable04, @c_Lottable05, 
              @n_ErrNo OUTPUT, @c_ErrMsg OUTPUT '    
         SET @cSQLParam =    
            '@n_Mobile        INT,           ' +
            '@c_LotLabel01    NVARCHAR( 20), ' +    
            '@c_LotLabel02    NVARCHAR( 20), ' +   
            '@c_LotLabel03    NVARCHAR( 20), ' +    
            '@c_LotLabel04    NVARCHAR( 20), ' +    
            '@c_LotLabel05    NVARCHAR( 20), ' +      
            '@c_Lottable01    NVARCHAR( 18), ' +      
            '@c_Lottable02    NVARCHAR( 18), ' +      
            '@c_Lottable03    NVARCHAR( 18), ' +      
            '@c_Lottable04    NVARCHAR( 16), ' +      
            '@c_Lottable05    NVARCHAR( 16), ' +      
            '@n_ErrNo         INT           OUTPUT, ' +
            '@c_ErrMsg        NVARCHAR( 20) OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            @nMobile, @c_LotLabel01, @c_LotLabel02, @c_LotLabel03, @c_LotLabel04, @c_LotLabel05, @c_Lottable01, @c_Lottable02, @c_Lottable03, @c_Lottable04, @c_Lottable05, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT 

         GOTO Quit
      END    
   END
      
   SET @nLot01Blank = 0
   SET @nLot02Blank = 0
   SET @nLot03Blank = 0
   SET @nLot04Blank = 0
   SET @nLot05Blank = 0

   IF ISNULL( @c_LotLabel01, '') <> ''
   BEGIN
      IF ISNULL(@c_Lottable01, '') = ''
      BEGIN
         SET @nLot01Blank = 1
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Lottable01  
         GOTO Quit
      END
   END

   IF ISNULL( @c_LotLabel02, '') <> ''
   BEGIN
      IF ISNULL(@c_Lottable02, '') = '' AND @nLot01Blank = 0
      BEGIN
         SET @nLot02Blank = 1
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Lottable02  
         GOTO Quit
      END
   END
   
   IF ISNULL( @c_LotLabel03, '') <> ''
   BEGIN
      IF ISNULL(@c_Lottable03, '') = '' AND @nLot02Blank = 0
      BEGIN
         SET @nLot03Blank = 1
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- Lottable03   
         GOTO Quit
      END
   END
   
   IF ISNULL( @c_LotLabel04, '') <> ''
   BEGIN
      IF (ISNULL(@c_Lottable04, '') = '' OR RDT.RDTFormatDate(@c_Lottable04) = '01/01/1900' OR RDT.RDTFormatDate(@c_Lottable04) = '1900/01/01')
          AND @nLot03Blank = 0
      BEGIN
         SET @nLot04Blank = 1
         EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04  
         GOTO Quit
      END
   END
   /*
   IF ISNULL( @c_LotLabel05, '') <> ''
   BEGIN
      IF (ISNULL(@c_Lottable05, '') = '' OR RDT.RDTFormatDate(@c_Lottable05) = '01/01/1900' OR RDT.RDTFormatDate(@c_Lottable05) = '1900/01/01')
          AND @nLot04Blank = 0
      BEGIN
         SET @nLot05Blank = 1
         EXEC rdt.rdtSetFocusField @nMobile, 10 -- Lottable05  
         GOTO Quit
      END
   END
   */
   IF ISNULL( @c_LotLabel01, '') <> ''
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Lottable01  
      GOTO Quit
   END

   IF ISNULL( @c_LotLabel02, '') <> ''
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- Lottable02  
      GOTO Quit
   END

   IF ISNULL( @c_LotLabel03, '') <> ''
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- Lottable03  
      GOTO Quit
   END

   IF ISNULL( @c_LotLabel04, '') <> ''
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 8 -- Lottable04  
      GOTO Quit
   END

   IF ISNULL( @c_LotLabel05, '') <> ''
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 10 -- Lottable05  
      GOTO Quit
   END

   EXEC rdt.rdtSetFocusField @nMobile, 2 -- Lottable01  


   Quit:

END /* main procedure */

GO