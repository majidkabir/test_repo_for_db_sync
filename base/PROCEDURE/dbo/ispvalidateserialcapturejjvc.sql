SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure ispValidateSerialCaptureJJVC : 
--
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length     */

CREATE PROC [dbo].[ispValidateSerialCaptureJJVC]
   @c_DBName        NVARCHAR(20),
   @cCheckKey       NVARCHAR(20),   --what to check
   @cKey1           NVARCHAR(20),   --1st parameter passed in
   @cKey2           NVARCHAR(20),   --2nd parameter passed in
   @cOutPut1        NVARCHAR(20) OUTPUT,   --output parameter
   @cOutPut2        NVARCHAR(20) OUTPUT--,
--   @b_Success       int OUTPUT   --success or not
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   
   DECLARE @c_SQLStatement    nvarchar(4000),
           @b_debug           int,
           @n_err             int,
           @c_errmsg          NVARCHAR(512),
           @cSKU              NVARCHAR(20),
           @nSKUCount         int,  
           @cZone             NVARCHAR(18),
           @cExternOrderKey   NVARCHAR(50),    --tlting_ext
           @cOrderKey         NVARCHAR(10)
 
   SELECT @b_debug = 0

   IF dbo.fnc_RTRIM(@cKey1) IS NULL OR dbo.fnc_RTRIM(@cKey1) = '' 
   BEGIN
      RETURN
   END

   IF dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cCheckKey)) = 'UPC'
   BEGIN
   	SELECT @c_SQLStatement = N'SELECT @cSKU = UPC.SKU FROM ' 
		SELECT @c_SQLStatement = dbo.fnc_RTRIM(@c_SQLStatement) + ' ' + ISNULL(dbo.fnc_RTRIM(@c_DBName), '') + '.dbo.UPC UPC (NOLOCK) INNER JOIN ' 
		SELECT @c_SQLStatement = dbo.fnc_RTRIM(@c_SQLStatement) + ' ' + ISNULL(dbo.fnc_RTRIM(@c_DBName), '') + '.dbo.SKU SKU (NOLOCK) ' 
         + ' ON UPC.SKU = SKU.SKU AND UPC.STORERKEY = SKU.STORERKEY '  
		   + ' WHERE UPC.UPC = N''' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cKey1)) + ''''			
		   + ' AND UPC.STORERKEY = N''' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cKey2)) + ''''			
		EXEC sp_executesql @c_SQLStatement, N'@cSKU NVARCHAR(18) output', @cSKU output			
   END

   IF dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cCheckKey)) = 'SKU'
   BEGIN
   	SELECT @c_SQLStatement = N'SELECT @cZone = Zone, @cExternOrderKey = ExternOrderKey, @cOrderKey = OrderKey FROM ' 
		SELECT @c_SQLStatement = dbo.fnc_RTRIM(@c_SQLStatement) + ' ' + ISNULL(dbo.fnc_RTRIM(@c_DBName), '') + '.dbo.PICKHEADER ' 
		      + ' (NOLOCK) WHERE PICKHEADERKEY = N''' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cKey1)) + ''''			
		EXEC sp_executesql @c_SQLStatement, N'@cZone NVARCHAR(18) output, @cExternOrderKey NVARCHAR(20) output, 
      @cOrderKey NVARCHAR(10) output', @cZone output, @cExternOrderKey output, @cOrderKey output			

      IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP' 
      BEGIN
      	SELECT @c_SQLStatement = N'SELECT @nSKUCount = COUNT(PD.SKU) FROM ' 
   		SELECT @c_SQLStatement = dbo.fnc_RTRIM(@c_SQLStatement) + ' ' + ISNULL(dbo.fnc_RTRIM(@c_DBName), '') + '.dbo.REFKEYLOOKUP RKL (NOLOCK) INNER JOIN ' 
   		SELECT @c_SQLStatement = dbo.fnc_RTRIM(@c_SQLStatement) + ' ' + ISNULL(dbo.fnc_RTRIM(@c_DBName), '') + '.dbo.PICKDETAIL PD (NOLOCK) ' 
            + ' ON RKL.PickDetailKey = PD.PickDetailKey '  
	   	   + ' WHERE RKL.PickSlipNo = ''' + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cKey1)) + ''''			
		   EXEC sp_executesql @c_SQLStatement, N'@nSKUCount int output', @nSKUCount output			
      END   -- end for pickslip 'XD', 'LB', 'LP'          
      ELSE   --other pickslip type
      BEGIN
      	SELECT @c_SQLStatement = N'SELECT @nSKUCount = COUNT(OD.SKU) FROM ' 
   		SELECT @c_SQLStatement = dbo.fnc_RTRIM(@c_SQLStatement) + ' ' + ISNULL(dbo.fnc_RTRIM(@c_DBName), '') + '.dbo.ORDERDETAIL OD (NOLOCK) INNER JOIN '
   		SELECT @c_SQLStatement = dbo.fnc_RTRIM(@c_SQLStatement) + ' ' + ISNULL(dbo.fnc_RTRIM(@c_DBName), '') + '.dbo.PICKDETAIL PD (NOLOCK) '
   		      + ' ON OD.ORDERKEY = PD.ORDERKEY AND OD.ORDERLINENUMBER = PD.ORDERLINENUMBER '  
               + ' WHERE OD.LOADKEY = N''' + dbo.fnc_RTRIM(@cExternOrderKey) + ''''			
               + ' AND OD.ORDERKEY = CASE WHEN @cOrderKey = '''' THEN OD.OrderKey ELSE @cOrderKey END '	
               + ' AND PD.SKU = N''' + dbo.fnc_RTRIM(@cKey2) + ''''		
   		EXEC sp_executesql @c_SQLStatement, N'@cOrderKey NVARCHAR(20), @nSKUCount int output', @cOrderKey, @nSKUCount output			
      END   --end for other zone
   END   --end for other pickslip type

   IF dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cCheckKey)) = 'UPC'
   BEGIN
      IF ISNULL(dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cSKU)), '') <> ''         
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

   IF dbo.fnc_LTRIM(dbo.fnc_RTRIM(@cCheckKey)) = 'SKU'
   BEGIN
      IF @nSKUCount > 0
      BEGIN         
         SET @cOutPut1 = @nSKUCount    
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