SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_GetPackCartonID                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2019-11-08   1.0  Chermaine  Created                                       */
/* 2020-12-30   1.1  Chermaine  TPS-518 Add @PackCaptureNewLabelno config (cc01)*/
/* 2021-09-02   1.2  Chermaine  TPS-592 Add catonNo param (cc02)              */
/* 2021-09-05   1.3  Chermaine  TPS-11 ErrMsg add to rdtmsg (cc03)            */
/* 2024-01-15   1.4  YeeKung    TPS-847 Add configkey (yeekung01)             */
/* 2024-01-09   1.5  YeeKung    TPS-805 Add Extendedgenlabel (yeekung02)      */
/* 2024-09-20   1.6  YeeKung    Fix RDT ->API (yeekung03)                     */
/******************************************************************************/

CREATE   PROC [API].[isp_GetPackCartonID] (
   @json       NVARCHAR( MAX),
   @jResult    NVARCHAR( MAX) OUTPUT,
   @b_Success  INT = 1  OUTPUT,
   @n_Err      INT = 0  OUTPUT,
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE

   @cLangCode        NVARCHAR( 3),
   @c_StorerKey       NVARCHAR( 15),
      @cFacility        NVARCHAR( 5),
      @nFunc            INT,
   @cPickSlipNo      NVARCHAR( 10),

   @cOrderKey        NVARCHAR( 10),
   @cLoadKey         NVARCHAR( 10),
   @cPackDetailCartonID  NVARCHAR( 20),

   @cDropID          NVARCHAR( 20)= '',
   @cRefNo           NVARCHAR( 20)= '',
   @cRefNo2          NVARCHAR( 30)= '',
   @cUPC             NVARCHAR( 30)= '',

   @cPackDtlDropID   NVARCHAR( 20),
   @cPackDtlRefNo    NVARCHAR( 20),
   @cPackDtlRefNo2   NVARCHAR( 20),
   @cPackDtlUPC      NVARCHAR( 30),
   @cNewLine         NVARCHAR(1),
   @cGenLabelNo_SP   NVARCHAR(20),
   @c_LabelNo        NVARCHAR( 20) = '',
   @cUCCNo           NVARCHAR( 20),
   @nCartonNo        INT,
   @cCartonNo        NVARCHAR(3), --(cc02)
   @c_Option1        NVARCHAR(50),  --(cc01)
   @c_Option2        NVARCHAR(50),  --(cc01)
   @cOldUCCLabelNo   NVARCHAR( 20),

   --@cLabelLine       NVARCHAR(5),
   --@cSKU             NVARCHAR( 20),

   @cSQL             NVARCHAR(MAX),
   @cSQLParam        NVARCHAR(MAX),

   @c_authority            NVARCHAR(30),
   @cCaptureLabelNo  NVARCHAR( 1),
   @c_Identifier     NVARCHAR(2)    = '',
   @c_Packtype       NVARCHAR(1)    = '',
   @c_VAT            NVARCHAR(18)   = '',
   @c_nCounter       NVARCHAR(25)   = '',
   @c_Keyname        NVARCHAR(30)   = '',
   @c_PackNo_Long    NVARCHAR(250)  = '',
   @n_CheckDigit     INT = 0,
   @n_TotalCnt       INT = 0,
   @n_TotalOddCnt    INT = 0,
   @n_TotalEvenCnt   INT = 0,
   @n_Add            INT = 0,
   @n_Divide         INT = 0,
   @n_Remain         INT = 0,
   @n_OddCnt         INT = 0,
   @n_EvenCntt       INT = 0,
   @n_Odd            INT = 0,
   @n_Even           INT = 0,
   @c_CTNTrackNo     NVARCHAR(40)   = '',
   @cExtendedGenLBLSP NVARCHAR(20) 


DECLARE @CartonID TABLE (
      CartonID       NVARCHAR( 20)
)



SELECT @c_StorerKey=StorerKey, @cFacility=Facility,@nFunc=Func,@cPickSlipNo=PickSlipNo, @cCartonNo = CartonNo, @cLangCode = LangCode
FROM OPENJSON(@json)
WITH (
      StorerKey   NVARCHAR( 15),
      Facility    NVARCHAR( 5),
      Func        INT,
      PickSlipNo  NVARCHAR( 10),
      CartonNo    INT, --(cc02)
      LangCode    NVARCHAR( 3) --(cc03)
)
--SELECT  @c_StorerKey AS StorerKey, @cFacility AS Facility,@nFunc AS Func,@cPickSlipNo AS PickSlipNo

 SELECT @cExtendedGenLBLSP =SValue  
 FROM storerConfig WITH (NOLOCK)
WHERE configkey ='TPS-ExtendedGenLBLSP' 
   AND storerKey = @c_StorerKey 

IF ISNULL(@cExtendedGenLBLSP,'') NOT IN ('','0')  
BEGIN    
   IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedGenLBLSP AND type = 'P')    
   BEGIN  
      SET @cSQL = 'EXEC API.' + RTRIM( @cExtendedGenLBLSP) +  
      ' @cStorerKey, @cFacility, @nFunc, @cLangCode,@cPickSlipNo, @cCartonNo,' +   
      ' @cLabelNo OUTPUT,@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT ' 

      SET @cSQLParam =     
         '@cStorerKey      NVARCHAR( 15), ' +  
         '@cFacility       NVARCHAR( 5),  ' +   
         '@nFunc           INT,           ' +  
         '@cLangCode       NVARCHAR( 3),  ' +  
         '@cPickSlipNo     NVARCHAR( 30), ' + 
         '@cCartonNo       NVARCHAR(3),   ' +
         '@cLabelNo        NVARCHAR( 20)  OUTPUT, ' +  
         '@b_Success       INT            OUTPUT, ' +  
         '@n_Err           INT            OUTPUT, ' +  
         '@c_ErrMsg        NVARCHAR( 255)  OUTPUT'  
  
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
         @c_StorerKey, @cFacility, @nFunc, @cLangCode,@cPickSlipNo, @cCartonNo,   
         @c_LabelNo OUTPUT,@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT 

      IF @n_Err <> 0
         GOTO EXIT_SP
   END
END
ELSE
BEGIN
                  
   -- Config to allow user to key in Label no
   IF @c_LabelNo = ''
   BEGIN
         --SELECT 'PackCaptureNewLabelno'
      EXECUTE nspGetRight null,
      @c_StorerKey,             -- Storerkey
      '',                           -- Sku
      'PackCaptureNewLabelno', -- Configkey
      @b_success            OUTPUT,
      @c_authority      OUTPUT,
      @n_err               OUTPUT,
      @c_errmsg            OUTPUT,
      @c_Option1     OUTPUT,  --(cc01)
      @c_Option2     OUTPUT   --(cc01)

      IF @c_authority = '1' AND @c_Option2 <> 'N' --(cc01)
      BEGIN
            --SET @cCaptureLabelNo = '1'
            SET @b_Success = 0
         SET @n_Err = 1000451
         SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Need LableNo. Function : isp_GetPackCartonID'
            GOTO EXIT_SP
      END
   END

   --config = GenLabelNo_SP
   IF @c_LabelNo = ''
   BEGIN
         --SELECT 'GenLabelNo_SP'

      EXECUTE nspGetRight null,
      @c_StorerKey,             -- Storerkey
      '',                           -- Sku
      'GenLabelNo_SP',       -- Configkey
      @b_success            OUTPUT,
      @c_authority      OUTPUT,
      @n_err               OUTPUT,
      @c_errmsg            OUTPUT

      IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_authority) AND type = 'P')
      BEGIN
         --Gen Label
         EXECUTE api.isp_TP_GenLabelNo_Wrapper
         @c_PickSlipNo = @cPickSlipno,
         @n_CartonNo   = @cCartonNo,  --(cc02)
         @c_LabelNo    = @c_LabelNo   OUTPUT

         IF @c_LabelNo <> ''
         BEGIN
            GOTO EXIT_SP
         END
      END
   END

   --config = GenSSCCLabel
   IF @c_LabelNo = ''
   BEGIN
         --SELECT 'GenSSCCLabel'
      EXECUTE nspGetRight null,
      @c_StorerKey,             -- Storerkey
      '',                           -- Sku
      'GenSSCCLabel',       -- Configkey
      @b_success            OUTPUT,
      @c_authority      OUTPUT,
      @n_err               OUTPUT,
      @c_errmsg            OUTPUT

      IF @c_authority IN ('1','2')
      BEGIN
          --Gen Label
         EXECUTE isp_TP_GenSSCCLabel_Wrapper
         @c_PickSlipNo = @cPickSlipno,
         @n_CartonNo   = 0,
         @c_LabelNo    = @c_LabelNo   OUTPUT

         IF @c_LabelNo <> ''
         BEGIN
            GOTO EXIT_SP
         END
      END
   END

   --config = GenUCCLabelNoConfig
   IF @c_LabelNo = ''
   BEGIN
         --SELECT 'GenUCCLabelNoConfig'

      EXECUTE nspGetRight null,
      @c_StorerKey,             -- Storerkey
      '',                           -- Sku
      'GenUCCLabelNoConfig',       -- Configkey
      @b_success            OUTPUT,
      @c_authority      OUTPUT,
      @n_err               OUTPUT,
      @c_errmsg            OUTPUT

      IF @c_authority = '1'
      BEGIN
         SET @c_Identifier = '00'
         SET @c_Packtype = '0'
         SET @c_LabelNo = ''

         SELECT @c_VAT = ISNULL(Vat,'')
         FROM Storer WITH (NOLOCK)
         WHERE Storerkey = @c_Storerkey


         SELECT @cOldUCCLabelNo = sValue 
         FROM dbo.StorerConfig WITH (NOLOCK) 
         WHERE StorerKey = @c_StorerKey 
            AND configKey = 'TPS-OldUCCLabelNoCfg'  


         IF ISNULL(@c_VAT,'') = ''
            SET @c_VAT = '000000000'

         IF @cOldUCCLabelNo <>'1'
         BEGIN
            IF LEN(@c_VAT) <> 9
               SET @c_VAT = RIGHT('000000000' + RTRIM(LTRIM(@c_VAT)), 9)

            --(Wan01) - Fixed if not numeric
            IF ISNUMERIC(@c_VAT) = 0
            BEGIN
               SET @n_Err = 1000452
               SET @c_errmsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Execution Error : Vat is not a numeric value. (isp_GLBL20). Function : isp_GetPackCartonID'
               GOTO EXIT_SP
            END
         END

         --Fixed if not numeric

         SELECT @c_PackNo_Long = Long
         FROM  CODELKUP (NOLOCK)
         WHERE ListName = 'PACKNO'
         AND Code = @c_Storerkey

         IF ISNULL(@c_PackNo_Long,'') = ''
            SET @c_Keyname = 'TBLPackNo'
         ELSE
            SET @c_Keyname = 'PackNo' + LTRIM(RTRIM(@c_PackNo_Long))

         EXECUTE nspg_getkey
         @c_Keyname ,
         7,
         @c_nCounter     Output ,
         @b_success      = @b_success output,
         @n_err          = @n_err output,
         @c_errmsg       = @c_errmsg output,
         @b_resultset    = 0,
         @n_batch        = 1

         SET @c_LabelNo = @c_Identifier + @c_Packtype + RTRIM(@c_VAT) + RTRIM(@c_nCounter) --+ @n_CheckDigit

         SET @n_Odd = 1
         SET @n_OddCnt = 0
         SET @n_TotalOddCnt = 0
         SET @n_TotalCnt = 0

         WHILE @n_Odd <= 20
         BEGIN
            IF ISNUMERIC(SUBSTRING(@c_LabelNo, @n_Odd, 1)) = 1
            BEGIN
               SET @n_OddCnt = CAST(SUBSTRING(@c_LabelNo, @n_Odd, 1) AS INT)
            END
            ELSE
               SET @n_OddCnt = 0
            SET @n_TotalOddCnt = @n_TotalOddCnt + @n_OddCnt
            SET @n_Odd = @n_Odd + 2
         END

         SET @n_TotalCnt = (@n_TotalOddCnt * 3)

         SET @n_Even = 2
         SET @n_EvenCntt = 0
         SET @n_TotalEvenCnt = 0

         WHILE @n_Even <= 20
         BEGIN
            IF ISNUMERIC(SUBSTRING(@c_LabelNo, @n_Even, 1)) = 1
            BEGIN
               SET @n_EvenCntt = CAST(SUBSTRING(@c_LabelNo, @n_Odd, 1) AS INT)
            END
            ELSE
               SET @n_EvenCntt = 0

            SET @n_TotalEvenCnt = @n_TotalEvenCnt + @n_EvenCntt
            SET @n_Even = @n_Even + 2
         END

         SET @n_Add = 0
         SET @n_Remain = 0
         SET @n_CheckDigit = 0

         SET @n_Add = @n_TotalCnt + @n_TotalEvenCnt
         SET @n_Remain = @n_Add % 10
         SET @n_CheckDigit = 10 - @n_Remain

         IF @n_CheckDigit = 10
            SET @n_CheckDigit = 0

         SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@n_CheckDigit AS NVARCHAR( 1))
      END   -- GenUCCLabelNoConfig
      ELSE
      BEGIN
            --SELECT 'PACKNO'
         EXECUTE nspg_GetKey
            'PACKNO',
            10 ,
            @c_LabelNo  OUTPUT,
            @b_success  OUTPUT,
            @n_err      OUTPUT,
            @c_errmsg   OUTPUT
      END
   END
END


IF @c_LabelNo <> ''
BEGIN
      SET @b_Success = 1
      SET @jResult = '[{'+@c_LabelNo+'}]'
      --SELECT @c_LabelNo AS labelNo
END
ELSE
BEGIN
      SET @b_Success = 0
   SET @n_Err = 1000453
   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')--'Fail to retrieve LableNo. Function : isp_GetPackCartonID'
END

EXIT_SP:
IF @c_LabelNo <> ''
BEGIN
      SET @b_Success = 1
      SET @jResult = '[{'+@c_LabelNo+'}]'
END


SET QUOTED_IDENTIFIER OFF

GO