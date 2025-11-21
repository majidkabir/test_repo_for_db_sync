SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: isp0000P_WSIML_HK_CR_WMS_getWaybill_Import_SubSP   */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Call SP in HKWMS for Printing Function                      */  
/*                                                                      */  
/* Called By: isp0000P_WSIML_HK_DHL_WMS_getWaybill_Import               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/************************************************************************/  
CREATE PROC [dbo].[isp0000P_WSIML_HK_CR_WMS_getWaybill_Import_SubSP](
       @c_DataStream             NVARCHAR(10)
     , @c_StorerKey              NVARCHAR(15)
	  , @c_PDF_WinPrinter			NVARCHAR(128)
     , @cPrintCommand            NVARCHAR(MAX)
     , @n_Err                    INT            = 0 OUTPUT
     , @c_ErrMsg                 NVARCHAR(215)  = '' OUTPUT
) AS
BEGIN
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @tRDTPrintJob AS VariableTable

   EXEC RDT.rdt_Print '0', '593', 'ENG', 0, 1, '', @c_StorerKey, @c_PDF_WinPrinter, '', 
        'PDFWBILL',     -- Report type
        @tRDTPrintJob,    -- Report params
        'isp0000P_WSIML_HK_CR_WMS_getWaybill_Import_SubSP', 
        @n_Err  OUTPUT,
        @c_ErrMsg OUTPUT,
        1,
        @cPrintCommand

END
         

GO