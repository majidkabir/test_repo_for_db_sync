SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: rdt_593_WS_SSCCGen01                                */
/* Creation Date: 2024-09-02                                            */
/* Copyright: Maersk                                                    */
/* Written by: WSE016                                                   */
/*                                                                      */
/* Purpose: ?                                                           */
/*        :                                                             */
/* Called By: Fn593 - RDT Re-Print                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Purposes                                       */
/* 02/09/2024   WSE016   Created combine script to genrate SSCC via RDT */
/************************************************************************/

CREATE   PROC [RDT].[rdt_593_WS_SSCCGen01]
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR(3),
   @cStorerKey NVARCHAR(15),
   @cOption    NVARCHAR(1),
   @cParam1    NVARCHAR(20), --LPNCopies
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
--



AS
--BEGIN

    SET NOCOUNT ON
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
    @StartSSCC    NUMERIC (20)
   ,@NewSSCC      NUMERIC (20)
   ,@FinalSSCC    NVARCHAR (20)
   ,@ExisitngSSCC NVARCHAR (20)
   ,@NCounter     NUMERIC (10)  
 --
   ,@cPaperPrinter     NVARCHAR( 10)
   ,@cLabelPrinter     NVARCHAR( 10)
   ,@cUserName         NVARCHAR( 18)
   ,@cFacility         NVARCHAR( 5)
   ,@cPalletLabel      NVARCHAR( 20)
   ,@nInputKey         INT = 1 -- Temp Fix

/* --commented out as I can log to RDT in CDT
   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility,
          @cStorerkey = StorerKey,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
 */  
SET @cLabelPrinter= 'ZM_TEST'
set @cPaperPrinter = NULL
set @cFacility = 'HR009'
Set @cStorerkey ='HRPUMA'
set @cUserName = 'WSE016'

-- */
DECLARE @tSSCCList VariableTable


   IF @nInputKey = 1
   BEGIN
      IF @nStep IN (1, 2) --Temp Fix
      BEGIN

		  IF @cOption = '1' 

    SET @nErrNo    = 0
    SET @cErrMsg   = ''
    SET @NCounter  = 0

    select @StartSSCC = short
    from Codelkup WITH (NOLOCK)
    where storerkey = @cStorerKey and LISTNAME = 'WS_SSCCGen';

    select @FinalSSCC = long
    from Codelkup WITH (NOLOCK)
    where storerkey = @cStorerKey and LISTNAME = 'WS_SSCCGen';

    select TOP 1 @ExisitngSSCC = id
    from LOTxLOCxID  WITH (NOLOCK)
    where storerkey = @cStorerKey and qty> 0;


     select TOP 1 @cPalletLabel = Code2 
    from Codelkup WITH (NOLOCK)
    where storerkey = @cStorerKey and LISTNAME = 'WS_SSCCGen';


    /* errors handling */
    IF CONVERT(NVARCHAR (20), (@StartSSCC+1)) >= CONVERT(NVARCHAR (20),@ExisitngSSCC)
BEGIN
        PRINT 'LPN already exists';

        SET @nErrNo = 69020
        SET @cErrMsg = 'NSQL' + CONVERT(CHAR(5), @nErrNo) + ': LPN already exists '  + '(rdt_WS_SSCCGen01)'
RETURN
    END

    IF CONVERT(NVARCHAR (20), (@StartSSCC+1)) >= CONVERT(NVARCHAR (20),@FinalSSCC)
BEGIN
        PRINT 'Max LPN limit has been reach';
        SET @nErrNo = 69020
        SET @cErrMsg = 'NSQL' + CONVERT(CHAR(5), @nErrNo) + ': Max LPN limit has been reach'  + '(rdt_WS_SSCCGen01)'
RETURN
    END


    /* SSCC Genarator */


            INSERT INTO @tSSCCList (Variable, Value) VALUES
            ( '@cStorerKey',  @cStorerKey),
            ( '@LPNCopies',   @cParam1)

    while @NCounter < @cParam1
BEGIN

        select @NewSSCC = short+1
        from Codelkup  WITH (NOLOCK)
        where storerkey = @cStorerKey and LISTNAME = 'WS_SSCCGen';

        update Codelkup set short = @NewSSCC  where storerkey = @cStorerKey and LISTNAME = 'WS_SSCCGen';

        update Codelkup set UDF02 = format(cast(getdate() as date),'yyyyMMdd')  where storerkey = @cStorerKey and LISTNAME = 'WS_SSCCGen';

        PRINT @NewSSCC -- for test only

        /* add print SP for label print here */

       -- /*
            --  IF @cPalletLabel <> ''
        -- BEGIN



                  EXEC RDT.rdt_Print 
                  @nMobile, 
                  @nFunc, 
                  @cLangCode, 
                  @nStep, 
                  @nInputKey, 
                  @cFacility, 
                  @cStorerKey, 
                  @cLabelPrinter, 
                  @cPaperPrinter,
                  @cPalletLabel, -->'RShpLbl03', -- Report type
                  @tSSCCList, -- Report params
                  --'isp_WS_HUSQSSCCGen01',
                  'rdt_593_WS_SSCCGen01',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit
      -- */

        set  @NCounter =@NCounter +1

     END

   END
END
Quit:
--END


GO