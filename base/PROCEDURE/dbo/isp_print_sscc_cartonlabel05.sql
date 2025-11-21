SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_Print_SSCC_CartonLabel05             		      */
/* Creation Date: 15-Mar-2011                                    			*/
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  HK HA - Print SSCC Carton Label (SOS205448)       		   */
/*                                                                      */
/*                                                                      */
/* Usage: Call by dw = r_dw_sscc_cartonlabel_05                         */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 15-Mar-2011  James     1.0   Created                  					*/
/************************************************************************/

CREATE PROC [dbo].[isp_Print_SSCC_CartonLabel05] ( 
   @cLoadKey      NVARCHAR( 10),
   @cLabelNo      NVARCHAR( 20),
   @cFilePath     NVARCHAR(100) 
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Declare temp table
   DECLARE @tTempResult TABLE (
         StorerKey        NVARCHAR( 15) NULL,
         LoadKey          NVARCHAR( 10) NULL,
         Company          NVARCHAR( 45) NULL,
         Addr1            NVARCHAR( 45) NULL,
         Addr2            NVARCHAR( 45) NULL,
         Addr3            NVARCHAR( 45) NULL,
         C_Company        NVARCHAR( 45) NULL,
         C_Addr1          NVARCHAR( 45) NULL,
         C_Addr2          NVARCHAR( 45) NULL,
         C_Addr3          NVARCHAR( 45) NULL,
         LabelNo          NVARCHAR( 20) NULL, 
         Barcodehr        NVARCHAR( 50) NULL, 
         FilePath         NVARCHAR(100) NULL  
         )

   DECLARE
      @b_debug             int,
      @nMobile             int, 
      @cLangCode           NVARCHAR( 3), 
      @nErrNo              int, 
      @cErrMsg             NVARCHAR( 20),
      @cStorerKey          NVARCHAR( 15), 
      @cNewLabelNo         NVARCHAR( 20), 
      @cBarcode            NVARCHAR( 50), 
      @cBarcodehr          NVARCHAR( 50)   -- human readable

   SELECT TOP 1 @cStorerKey = StorerKey FROM dbo.Orders WITH (NOLOCK) WHERE LoadKey = @cLoadKey

   SET @nMobile = 0

   SET @cBarcodehr = master.dbo.fnc_GetCharASCII(202) + @cLabelNo

   INSERT INTO @tTempResult 
   (StorerKey, LoadKey, Company, Addr1, Addr2, Addr3, C_Company, C_Addr1, C_Addr2, C_Addr3, LabelNo, Barcodehr, FilePath)
   SELECT TOP 1 @cStorerKey AS StorerKey, @cLoadKey AS LoadKey, S.Company, S.Address1, S.Address2, S.Address3, 
   C_Company, C_Address1, C_Address2, C_Address3, @cLabelNo AS LabelNo, @cBarcodehr as Barcodehr, @cFilePath as FilePath 
   FROM dbo.Orders O WITH (NOLOCK) 
   JOIN dbo.Storer S WITH (NOLOCK) ON O.StorerKey = S.StorerKey
   WHERE O.LoadKey = @cLoadKey
   
   SELECT * FROM @tTempResult
    
    
END

GO