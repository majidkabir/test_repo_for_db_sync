SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SerialNoCapture_Validate_LOTNO                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Validation for Serial Number Capture function               */
/*          Called by rdtfnc_SerialNoCapture                            */
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
/* Date        Rev  Author   Purposes                                   */
/* 22-Nov-2007 1.0  Vicky    Created for SOS#91982                      */
/* 02-Sep-2008 1.1  Vicky    Modify to cater for SQL2005 (Vicky01)      */ 
/* 02-Dec-2009 1.2  Vicky    Revamp SP for the purpose of RDT to WMS    */
/*                           take out DBName from parameter (Vicky02)   */ 
/************************************************************************/

CREATE PROC [RDT].[rdt_SerialNoCapture_Validate_LOTNO]
   @cCheckKey       NVARCHAR(20),   --what to check
   @cKey1           NVARCHAR(20),   --1st parameter passed in
   @cKey2           NVARCHAR(20),   --2nd parameter passed in
   @cKey3           NVARCHAR(20),   --3rd parameter passed in
   @cKey4           NVARCHAR(20),   --4th parameter passed in
   @cKey5           NVARCHAR(20),   --5th parameter passed in
   @cOutPut1        NVARCHAR(20) OUTPUT,   --output parameter
   @cOutPut2        NVARCHAR(20) OUTPUT--,
AS
BEGIN
   DECLARE @c_SQLStatement    nvarchar(4000),
           @b_debug           int,
           @n_err             int,
           @c_errmsg          NVARCHAR(512),
           @cSKU              NVARCHAR(20),
           @nSKUCount         int,  
           @cZone             NVARCHAR(18),
           @cExternOrderKey   NVARCHAR(20),
           @cOrderKey         NVARCHAR(10),
           @b_Success         int
          
   SELECT @b_debug = 0

   IF ISNULL(RTRIM(@cKey1), '') = '' -- (Vicky01)
   BEGIN
      RETURN
   END

   IF ISNULL(LTRIM(RTRIM(@cCheckKey)), '') = 'LOTNO' -- (Vicky01)
   BEGIN--start check duplicate of serialno + Lot#
      SELECT @b_success = 1
      --EXEC ispCheckKeyExists @c_DBName, 'SERIALNO', 'StorerKey', @cKey2, 'LotNo', @cKey1,  @b_success  OUTPUT, 'SerialNo', @cKey3, '', ''

      -- (Vicky02) - Start
      IF NOT EXISTS (SELECT 1 FROM dbo.SerialNO WITH (NOLOCK) WHERE Storerkey = @cKey2 AND SerialNo = @cKey3 AND LotNo = @cKey1)
      BEGIN
        SELECT @b_success = 0
      END
      -- (Vicky02) - End

      SET @cOutPut1 = @b_success
      SET @cOutPut2 = ''
   END--end check for duplicate of serialno      
END -- procedure



GO