SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO




/***************************************************************************/
/* Store procedure: rdtfnc_UtilRePrinting                                  */
/*                                                                         */
/* 2024-09-24 TEST  xxxx Util-Reprinting by DB   */
/***************************************************************************/
CREATE      PROC [RDT].[rdtfnc_UtilPrintPS](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT  -- screen limitation, 20 char max   
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
 
GO