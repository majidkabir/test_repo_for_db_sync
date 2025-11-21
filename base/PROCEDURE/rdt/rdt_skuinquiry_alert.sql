SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SKUInquiry_Alert                                */
/*                                                                      */
/* Purpose: Insert alert                                                */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2011-05-26 1.0  Ung        Created                                   */
/************************************************************************/

CREATE PROC [RDT].[rdt_SKUInquiry_Alert] (
   @nMobile      INT,
   @nFunc        INT, 
   @cStorerKey   NVARCHAR( 15), 
   @cFacility    NVARCHAR( 5), 
   @cInquiry_SKU NVARCHAR( 20), 
   @cCaseUOM     NVARCHAR( 5), 
   @cEAUOM       NVARCHAR( 5), 
   @cCS_PL       NVARCHAR( 5),   @cInCS_PL    NVARCHAR( 5), 
   @cEA_CS       NVARCHAR( 5),   @cInEA_CS    NVARCHAR( 5), 
   @cPickLOC     NVARCHAR( 10),  @cInPickLOC  NVARCHAR( 10), 
   @cMin         NVARCHAR( 5),   @cInMin      NVARCHAR( 5),  
   @cMax         NVARCHAR( 5),   @cInMax      NVARCHAR( 5)
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE @b_success   INT
DECLARE @n_err       INT
DECLARE @c_errmsg    NVARCHAR( 255)
DECLARE @c_Alert     NVARCHAR( 255)

-- CS_PL or EA_CS changed
IF @cCS_PL <> @cInCS_PL OR
   @cEA_CS <> @cInEA_CS
BEGIN
   SET @c_Alert = 'SKU = ' + RTRIM( @cInquiry_SKU)

   IF @cCS_PL <> @cInCS_PL
      SET @c_Alert = @c_Alert + ' Pallet QTY WMS=' + RTRIM( @cCS_PL) + ' ' + RTRIM( @cCaseUOM) + ' Suggest=' + RTRIM( @cInCS_PL) + ' ' + RTRIM( @cCaseUOM)
         
   IF @cEA_CS <> @cInEA_CS
      SET @c_Alert = @c_Alert + ' Case QTY WMS=' + RTRIM( @cEA_CS) + ' ' + RTRIM( @cEAUOM) + ' Suggest=' + RTRIM( @cInEA_CS) + ' ' + RTRIM( @cEAUOM)

   EXECUTE dbo.nspLogAlert
      @c_ModuleName   = 'SKUMasterCheck',
      @c_AlertMessage = @c_Alert,
      @n_Severity     = 0,
      @b_success      = @b_success OUTPUT,
      @n_err          = @n_err     OUTPUT,
      @c_errmsg       = @c_errmsg  OUTPUT
END

-- Pickloc, min, max changed
IF @cMin <> @cInMin OR
   @cMax <> @cInMax OR
   @cPickLOC <> @cInPickLOC
BEGIN
   SET @c_Alert = 'SKU = ' + RTRIM( @cInquiry_SKU)
   
   IF @cPickLOC <> @cInPickLOC
   BEGIN
      IF @cPickLOC = '' SET @cPickLOC = 'NO PICKLOC'
      SET @c_Alert = @c_Alert + ' PICK LOC WMS=' + RTRIM( @cPickLOC) + ' Suggest=' + RTRIM( @cInPickLOC)
   END

   IF @cMin <> @cInMin
      SET @c_Alert = @c_Alert + ' MIN WMS=' + RTRIM( @cMin) + ' ' + RTRIM( @cCaseUOM) + ' Suggest=' + RTRIM( @cInMin) + ' ' + RTRIM( @cCaseUOM)

   IF @cMax <> @cInMax
      SET @c_Alert = @c_Alert + ' MAX WMS=' + RTRIM( @cMax) + ' ' + RTRIM( @cCaseUOM) + ' Suggest=' + RTRIM( @cInMax) + ' ' + RTRIM( @cCaseUOM)

   EXECUTE dbo.nspLogAlert
      @c_ModuleName   = 'SKUMasterCheck',
      @c_AlertMessage = @c_Alert,
      @n_Severity     = 0,
      @b_success      = @b_success OUTPUT,
      @n_err          = @n_err     OUTPUT,
      @c_errmsg       = @c_errmsg  OUTPUT
END

GO