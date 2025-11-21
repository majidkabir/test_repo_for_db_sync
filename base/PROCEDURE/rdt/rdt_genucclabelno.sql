SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Generate UCC Label No                                       */
/*                                                                      */
/* Called from RDT Scan & Pack                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2008-12-01 1.0  James      Created                                   */
/* 2010-08-06 1.2  Leong      Bug fix (Leong01)                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_GenUCCLabelNo] (
   @cStorerKey NVARCHAR( 15),
   @nMobile    int,
   @cLabelNo   NVARCHAR( 20)   OUTPUT,
   @cLangCode  NVARCHAR( 3),
   @nErrNo     int         OUTPUT,
   @cErrMsg    NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
DECLARE
   @cErrMsg1       NVARCHAR( 20),
   @cErrMsg2       NVARCHAR( 20),
   @cErrMsg3       NVARCHAR( 20),
   @cErrMsg4       NVARCHAR( 20)

DECLARE
   @cIdentifier    NVARCHAR( 2),
   @cPacktype      NVARCHAR( 1),
   @cSUSR1         NVARCHAR( 20),
   @c_nCounter     NVARCHAR( 25),
   @b_success      INT,
   @n_err          INT,
   @c_errmsg       NVARCHAR( 250),
   @nCheckDigit    INT,
   @nTotalCnt      INT,
   @nTotalOddCnt   INT,
   @nTotalEvenCnt  INT,
   @nAdd           INT,
   @nDivide        INT,
   @nRemain        INT,
   @nOddCnt        INT,
   @nEvenCnt       INT,
   @nOdd           INT,
   @nEven          INT

BEGIN
   IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConfigKey = 'GenUCCLabelNoConfig'
         AND SValue = '1')
   BEGIN
      SET @cIdentifier = '00'
      SET @cPacktype = '0'
      SET @cLabelNo = ''

      SELECT @cSUSR1 = ISNULL(SUSR1, '0')
      FROM dbo.Storer WITH (NOLOCK)
      WHERE Storerkey = @cStorerkey
      AND Type = '1'

    IF LEN(@cSUSR1) >= 9
      BEGIN
         -- Leong01
         -- SET @nErrNo = 0
         -- SET @cErrMsg1 = '99999 Invalid'
         -- SET @cErrMsg2 = 'part barcode'
         -- EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
         --    @cErrMsg1, @cErrMsg2
         -- IF @nErrNo = 1
         -- BEGIN
         --    SET @cErrMsg1 = ''
         --    SET @cErrMsg2 = ''
         -- END
         SET @nErrNo = 99999
         SET @cErrMsg = 'Invld Barcode'
         GOTO Quit
      END   -- IF LEN(@cSUSR1) >= 9

      EXEC dbo.isp_getucckey
            @cStorerkey,
            9,
            @c_nCounter OUTPUT ,
            @b_success  OUTPUT,
            @n_err      OUTPUT,
            @c_errmsg   OUTPUT,
            0,
            1

      IF @b_success <> 1
      BEGIN
         -- Leong01
         -- SET @nErrNo = 0
         -- SET @cErrMsg1 = '99999 Get'
         -- SET @cErrMsg2 = 'ucc key fail'
         -- EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,
         --    @cErrMsg1, @cErrMsg2
         -- IF @nErrNo = 1
         -- BEGIN
         --    SET @cErrMsg1 = ''
         --    SET @cErrMsg2 = ''
         -- END
         SET @nErrNo = 99999
         SET @cErrMsg = 'GenUCCKeyFail'
         GOTO Quit
      END

      IF LEN(@cSUSR1) <> 8
         SELECT @cSUSR1 = RIGHT('0000000' + CAST(@cSUSR1 AS NVARCHAR( 7)), 7)

      SET @cLabelNo = @cIdentifier + @cPacktype + RTRIM(@cSUSR1) + RTRIM(@c_nCounter) --+ @nCheckDigit

      SET @nOdd = 1
      SET @nOddCnt = 0
      SET @nTotalOddCnt = 0
      SET @nTotalCnt = 0

      WHILE @nOdd <= 20
      BEGIN
         SET @nOddCnt = CAST(SUBSTRING(@cLabelNo, @nOdd, 1) AS INT)
         SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt
         SET @nOdd = @nOdd + 2
      END

      SET @nTotalCnt = (@nTotalOddCnt * 3)

      SET @nEven = 2
      SET @nEvenCnt = 0
      SET @nTotalEvenCnt = 0

      WHILE @nEven <= 20
      BEGIN
         SET @nEvenCnt = CAST(SUBSTRING(@cLabelNo, @nEven, 1) AS INT)
         SET @nTotalEvenCnt = @nTotalEvenCnt + @nEvenCnt
         SET @nEven = @nEven + 2
      END

      SET @nAdd = 0
      SET @nRemain = 0
      SET @nCheckDigit = 0

      SET @nAdd = @nTotalCnt + @nTotalEvenCnt
      SET @nRemain = @nAdd % 10
      SET @nCheckDigit = 10 - @nRemain

      IF @nCheckDigit = 10
         SET @nCheckDigit = 0

      SET @cLabelNo = ISNULL(RTRIM(@cLabelNo), '') + CAST(@nCheckDigit AS NVARCHAR( 1))
   END -- GenUCCLabelNoConfig
   ELSE
   BEGIN
      EXECUTE dbo.nspg_GetKey
         'PACKNO',
         10 ,
         @cLabelNo   OUTPUT,
         @b_success  OUTPUT,
         @n_err      OUTPUT,
         @c_errmsg   OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @nErrNo = 99999
         SET @cErrMsg = rdt.rdtgetmessage( 99999, @cLangCode, 'DSP') -- 'GetLBLNoFail'
         GOTO Quit
      END
   END
   Quit:
END

GO