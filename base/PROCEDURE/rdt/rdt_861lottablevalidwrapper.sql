SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/
/* Store procedure: rdt_861LottableValidWrapper                           */
/* Copyright      : Maersk WMS                                            */
/* Customer       : PMI                                                   */
/*                                                                        */
/* Date       Rev    Author  Purposes                                     */
/* 2025-03-02 1.0.0  NLT013  FCR-2519 Create                              */
/**************************************************************************/

CREATE   PROCEDURE rdt.rdt_861LottableValidWrapper (
   @nMobile                INT
   ,@nFunc                 INT
   ,@cSPName               NVARCHAR( 20)
   ,@cLangCode             NVARCHAR(  3)
   ,@cStorerKey            NVARCHAR( 15)
   ,@cFacility             NVARCHAR(  5)
   ,@nStep                 INT
   ,@nInputKey             INT
   ,@cUCCLottable1         NVARCHAR( 18)
   ,@cUCCLottable2         NVARCHAR( 18)
   ,@cUCCLottable3         NVARCHAR( 18)
   ,@dUCCLottable4         DATETIME
   ,@cLottable01           NVARCHAR( 18)
   ,@cLottable02           NVARCHAR( 18)
   ,@cLottable03           NVARCHAR( 18)
   ,@dLottable04           DATETIME     
   ,@tValidationData       VariableTable READONLY
   ,@nErrNo                INT           OUTPUT   
   ,@cErrMsg               NVARCHAR( 50) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQLStatement   NVARCHAR(MAX),
           @cSQLParms       NVARCHAR(MAX)

    IF @cSPName IS NULL OR @cSPName = ''
   BEGIN
      SET @nErrNo = 234251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Valid SP Required
      GOTO QUIT
   END

   IF @cStorerKey IS NULL OR @cStorerKey = ''
   BEGIN
      SET @nErrNo = 234252
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --StorerKey Required
      GOTO QUIT
   END
      
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@cSPName) AND type = 'P')
   BEGIN
      SET @cSQLStatement = N'EXEC RDT.' + TRIM(@cSPName) + 
            ' @nMobile,                @nFunc,                 @cLangCode,     '                 +
            ' @cStorerKey,             @cFacility,             @nStep,         '                 +
            ' @nInputKey,              @cUCCLottable1,         @cUCCLottable2, '                 +
            ' @cUCCLottable3,          @dUCCLottable4,         @cLottable01,   '                 +
            ' @cLottable02,            @cLottable03,           @dLottable04,   '                 +
            ' @tValidationData,        @nErrNo      OUTPUT,    @cErrMsg       OUTPUT '

      SET @cSQLParms = N'@nMobile                INT'                +
                        ',@nFunc                 INT'                +
                        ',@cLangCode             NVARCHAR(  3)'      +
                        ',@cStorerKey            NVARCHAR( 15)'      +
                        ',@cFacility             NVARCHAR(  5)'      +
                        ',@nStep                 INT'                +
                        ',@nInputKey             INT'                +
                        ',@cUCCLottable1         NVARCHAR( 18)'      +
                        ',@cUCCLottable2         NVARCHAR( 18)'      +
                        ',@cUCCLottable3         NVARCHAR( 18)'      +
                        ',@dUCCLottable4         DATETIME'           +
                        ',@cLottable01           NVARCHAR( 18)'      +
                        ',@cLottable02           NVARCHAR( 18)'      +
                        ',@cLottable03           NVARCHAR( 18)'      +
                        ',@dLottable04           DATETIME'           +
                        ',@tValidationData       VariableTable READONLY' +
                        ',@nErrNo                INT           OUTPUT   ' +
                        ',@cErrMsg               NVARCHAR( 50) OUTPUT'
                        
      
      EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
             @nMobile        
            ,@nFunc          
            ,@cLangCode      
            ,@cStorerKey     
            ,@cFacility      
            ,@nStep          
            ,@nInputKey      
            ,@cUCCLottable1  
            ,@cUCCLottable2  
            ,@cUCCLottable3  
            ,@dUCCLottable4  
            ,@cLottable01    
            ,@cLottable02    
            ,@cLottable03    
            ,@dLottable04    
            ,@tValidationData
            ,@nErrNo          OUTPUT
            ,@cErrMsg         OUTPUT
   END
   ELSE
   BEGIN
      SET @nErrNo = 234253
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Valid SP Does Not Exist
      GOTO QUIT
   END

END
Quit:

GO