SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_593Print37                                            */
/* Copyright      : LF                                                        */
/*                                                                            */
/* Purpose: Print PDF                                                         */
/*                                                                            */
/* Modifications log:                                                         */
/* Date        Rev  Author   Purposes                                         */
/* 2022-09-30  1.0  yeekung WMS-20900. Created                               */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_593Print37] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 2),
   @cParam1    NVARCHAR(20),  -- StorerKey
   @cParam2    NVARCHAR(20),  -- OrderKey
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelPrinter     NVARCHAR( 10)
 
   DECLARE @cPaperPrinter     NVARCHAR( 10)
   DECLARE @cFacility         NVARCHAR(20)
   DECLARE @nTotalCnt         INT
   DECLARE @cErrMsg01         NVARCHAR(20)
   DECLARE @cErrMsg02         NVARCHAR(20)
   DECLARE @cErrMsg03         NVARCHAR(20)
   DECLARE @cErrMsg04         NVARCHAR(20)
   DECLARE @cErrMsg05         NVARCHAR(20)

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cFacility = Facility
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   DECLARE @cOrderKey NVARCHAR( 10)
   DECLARE @cMBOLKey  NVARCHAR( 20)
   DECLARE @cNoCartonCnt1 NVARCHAR( 5)
   DECLARE @cNoCartonCnt2 NVARCHAR( 5)
   DECLARE @nNoCartonCnt1 INT = 0 
   DECLARE @nNoCartonCnt2 INT = 0
   DECLARE @cCurrentPage INT = 1

   -- Param mapping
   SET @cOrderKey = @cParam1
   SET @cNoCartonCnt1 = @cParam2
   SET @cNoCartonCnt2 = @cParam3

   -- Check orderkey
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 192251 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need orderkey
      GOTO Quit
   END

      
   IF NOT EXISTS(SELECT 1 FROM MBOLdetail (nolock)
                  where orderkey=@cOrderkey
                  )
   BEGIN
      SET @nErrNo = 192252
      SET @cErrMsg01 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Please Create
      SET @nErrNo = 192253
      SET @cErrMsg02 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOLKey

      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
      @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05  

      goto quit

   END


   IF EXISTS(SELECT 1 FROM MBOL MB (NOLOCK) JOIN
                  MBOLdetail MBD (nolock) ON MB.mbolkey=MBD.mbolkey
                  where orderkey=@cOrderkey
                  AND Status = '9'
            )
   BEGIN
      SET @nErrNo = 192254
      SET @cErrMsg01 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL shipped
      SET @nErrNo = 192255
      SET @cErrMsg02 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No printlabel

      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
      @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05  

      goto quit
   END

   IF @cNoCartonCnt1=''
   BEGIN
      SET @nErrNo = 192262
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn01NotBlank
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- cartontype1  
      goto quit
   END

   IF @cNoCartonCnt2 ='' 
   BEGIN
       SET @nErrNo = 192263
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ctn02NotBlank
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- cartontype2 
      goto quit
   END

   SET @nNoCartonCnt1 = CAST (@cNoCartonCnt1 AS INT)
   SET @nNoCartonCnt2 = CAST (@cNoCartonCnt2 AS INT)

   IF @nNoCartonCnt1 + @nNoCartonCnt2  = 0
   BEGIN
      SET @nErrNo = 192256
      SET @cErrMsg01 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pls Identity
      SET @nErrNo = 192257
      SET @cErrMsg02 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No of Carton

      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
      @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05  

   END
      
   IF @nNoCartonCnt1 + @nNoCartonCnt2  > 50
   BEGIN
      SET @nErrNo = 192258
      SET @cErrMsg01 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --<100cnt allow

      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
      @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05  
      
      goto quit
   END
      
   IF EXISTS(SELECT 1 FROM MBOL MB (NOLOCK) JOIN
                  MBOLdetail MBD (nolock) ON MB.mbolkey=MBD.mbolkey
                  where orderkey=@cOrderkey
                  AND Status <> '9'
                  AND (totalcartons>0
                     OR MBD.CtnCnt1 >0
                     OR MBD.CtnCnt2 > 0)
            )
   BEGIN
      SET @nErrNo = 192259
      SET @cErrMsg01 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL updated
      SET @nErrNo = 192260
      SET @cErrMsg01 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No print Label

      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
      @cErrMsg01, @cErrMsg02, @cErrMsg03, @cErrMsg04, @cErrMsg05  
      
      goto quit
   END

   SET @nTotalCnt =@nNoCartonCnt1 + @nNoCartonCnt2

   UPDATE MBOLdetail WITH (ROWLOCK)
   set totalcartons=@nTotalCnt,
        CtnCnt1=@nNoCartonCnt1,
        CtnCnt2=@nNoCartonCnt2
   where orderkey=@cOrderkey

   IF @@ERROR <>0
   BEGIN
      SET @nErrNo = 192261
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdMBOLFail
      goto quit
   END

   select @cMBOLKey=Mbolkey
   FROM MBOLdetail WITH (ROWLOCK)
   where orderkey=@cOrderkey

   WHILE @cCurrentPage<=@nTotalCnt
   BEGIN

      DECLARE @tDispatch AS VariableTable
      INSERT INTO @tDispatch (Variable, Value) VALUES
         ( '@cOrderKey',   @cOrderKey),
         ( '@cMBOLKey',   @cMBOLKey),
         ( '@cCurrentPage' , CAST (@cCurrentPage AS NVARCHAR(5)))
      


      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, '1', @cFacility, @cStorerkey, @cLabelPrinter, '',
         'DISPLBL', -- Report type
         @tDispatch, -- Report params
         'rdt_593Print37',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO QuiT

      DELETE @tDispatch

      SET @cCurrentPage = @cCurrentPage +1
   END

   Quit:
END

GO