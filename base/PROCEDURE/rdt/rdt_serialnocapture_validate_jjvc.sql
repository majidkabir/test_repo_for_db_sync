SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SerialNoCapture_Validate_JJVC                   */
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
/* ??-???-2006 1.0  James    Created                                    */
/* 26-Oct-2006 1.1  MaryVong Check PickHeader.ExternOrderKey is blank,  */
/*                           retrieve based on OrderKey only            */
/* 21-Nov-2006 1.2  James    Perfomance Tunning                         */
/* 02-Sep-2008 1.3  Vicky    Modify to cater for SQL2005 (Vicky01)      */ 
/* 02-Dec-2009 1.4  Vicky    Revamp SP for the purpose of RDT to WMS    */
/*                           take out DBName from parameter (Vicky02)   */ 
/************************************************************************/

CREATE PROC [RDT].[rdt_SerialNoCapture_Validate_JJVC]
   @cCheckKey       NVARCHAR(20),   --what to check
   @cKey1           NVARCHAR(20),   --1st parameter passed in
   @cKey2           NVARCHAR(20),   --2nd parameter passed in
   @cOutPut1        NVARCHAR(20) OUTPUT,   --output parameter
   @cOutPut2        NVARCHAR(20) OUTPUT--,
--   @b_Success       int OUTPUT   --success or not
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

   IF RTRIM(@cKey1) IS NULL OR RTRIM(@cKey1) = '' 
   BEGIN
      RETURN
   END

   IF LTRIM(RTRIM(@cCheckKey)) = 'UPC'
   BEGIN
         -- (Vicky02) - Start
         EXEC [RDT].[rdt_GETSKU]    
             @cStorerKey  = @cKey2,
             @cSKU        = @cKey1         OUTPUT,
             @bSuccess    = @b_Success     OUTPUT,
             @nErr        = @n_Err         OUTPUT,
             @cErrMsg     = @c_ErrMsg      OUTPUT

         
         IF @b_Success = 0
         BEGIN
           SELECT @cSKU = '' --not exists either in SKU or UPC
         END
         ELSE
         BEGIN
            SELECT @cSKU = @cKey1
         END
         -- (Vicky02) - End
   END

   IF LTRIM(RTRIM(@cCheckKey)) = 'SKU'
   BEGIN
      -- (Vicky02) - Start
   	SELECT @cZone = Zone, 
             @cExternOrderKey = ExternOrderKey, 
             @cOrderKey = OrderKey 
      FROM dbo.PICKHEADER WITH (NOLOCK) 
      WHERE PICKHEADERKEY = ISNULL(LTRIM(RTRIM(@cKey1)), '')
      -- (Vicky02) - End

      IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP' 
      BEGIN
         -- (Vicky02) - Start
      	SELECT TOP 1 @cSKU = PD.SKU 
         FROM dbo.REFKEYLOOKUP RKL WITH (NOLOCK) 
         INNER JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey)
	   	WHERE RKL.PickSlipNo = ISNULL(LTRIM(RTRIM(@cKey1)), '')
         -- (Vicky02) - End
      END   -- end for pickslip 'XD', 'LB', 'LP'          
      ELSE   --other pickslip type
      BEGIN         
         IF RTRIM(@cExternOrderKey) <> ''
         BEGIN
            -- (Vicky02) - Start
            IF @cOrderKey <> ''
            BEGIN
         	    SELECT TOP 1 @cSKU = OD.SKU 
                FROM dbo.ORDERDETAIL OD WITH (NOLOCK) 
                INNER JOIN dbo.PICKDETAIL PD WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON (OD.ORDERKEY = PD.ORDERKEY AND OD.ORDERLINENUMBER = PD.ORDERLINENUMBER)
                WHERE OD.LOADKEY = RTRIM(@cExternOrderKey)
                AND   PD.SKU = RTRIM(@cKey2)
                AND   OD.ORDERKEY = @cOrderKey
            END
            ELSE
            BEGIN
         	    SELECT TOP 1 @cSKU = OD.SKU 
                FROM dbo.ORDERDETAIL OD WITH (NOLOCK) 
                INNER JOIN dbo.PICKDETAIL PD WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON (OD.ORDERKEY = PD.ORDERKEY AND OD.ORDERLINENUMBER = PD.ORDERLINENUMBER)
                WHERE OD.LOADKEY = RTRIM(@cExternOrderKey)
                AND   PD.SKU = RTRIM(@cKey2)
            END
            -- (Vicky02) - End
         END
         ELSE
         -- If PickHeader.ExternOrderKey (LoadKey) is blank, retrieve based on OrderKey only
         -- Reason: Print discrete pickslip (zone = '8') not necessary having loadkey created
         BEGIN
            -- (Vicky02) - Start
            IF @cOrderKey <> ''
            BEGIN
         	    SELECT TOP 1 @cSKU = OD.SKU 
                FROM dbo.ORDERDETAIL OD WITH (NOLOCK) 
                INNER JOIN dbo.PICKDETAIL PD WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON (OD.ORDERKEY = PD.ORDERKEY AND OD.ORDERLINENUMBER = PD.ORDERLINENUMBER)
                WHERE PD.SKU = RTRIM(@cKey2)
                AND   OD.ORDERKEY = @cOrderKey
            END
            ELSE
            BEGIN
         	    SELECT TOP 1 @cSKU = OD.SKU 
                FROM dbo.ORDERDETAIL OD WITH (NOLOCK) 
                INNER JOIN dbo.PICKDETAIL PD WITH (NOLOCK, INDEX(PICKDETAIL_OrderDetStatus)) ON (OD.ORDERKEY = PD.ORDERKEY AND OD.ORDERLINENUMBER = PD.ORDERLINENUMBER)
                WHERE PD.SKU = RTRIM(@cKey2)
            END
            -- (Vicky02) - End
         END
      END   --end for other zone
   END   --end for other pickslip type

   IF LTRIM(RTRIM(@cCheckKey)) = 'SERIALNO'   
   BEGIN--start check duplicate of serialno
      SELECT @b_success = 1
--      EXEC ispCheckKeyExists @c_DBName, 'SERIALNO', 'StorerKey', @cKey2, 'SERIALNO', @cKey1, @b_success  OUTPUT	   

      -- (Vicky02) - Start
      IF NOT EXISTS (SELECT 1 FROM dbo.SerialNO WITH (NOLOCK) WHERE Storerkey = @cKey2 AND SerialNo = @cKey1)
      BEGIN
        SELECT @b_success = 0
      END
      -- (Vicky02) - End

      SET @cOutPut1 = @b_success
      SET @cOutPut2 = ''
   END--end check for duplicate of serialno   

   IF LTRIM(RTRIM(@cCheckKey)) = 'UPC'
   BEGIN
      IF ISNULL(LTRIM(RTRIM(@cSKU)), '') <> ''         
      BEGIN         
         SET @cOutPut1 = @cSKU    
         SET @cOutPut2 = ''
      END
      ELSE
      BEGIN
         SET @cOutPut1 = ''
         SET @cOutPut2 = ''
      END
    END   --end for 'UPC'

   IF LTRIM(RTRIM(@cCheckKey)) = 'SKU'
   BEGIN
      IF ISNULL(LTRIM(RTRIM(@cSKU)), '') <> ''
      BEGIN         
         SET @cOutPut1 = 1
         SET @cOutPut2 = @cOrderKey    
      END
      ELSE
      BEGIN
         SET @cOutPut1 = '0'
         SET @cOutPut2 = ''
      END
    END   --end for 'SKU'
      
END -- procedure


GO