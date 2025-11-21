SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: rdt_CycleCount_rdtGetConfig                        */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2006-10-17   Shong         Created                                   */
/* 2017-11-06   James         Fix ansi option (james01)                 */
/************************************************************************/
CREATE PROC [RDT].[rdt_CycleCount_rdtGetConfig](
   @nFunction_ID INT, 
   @cConfigKey   NVARCHAR( 30), 
   @cCCRefNo     NVARCHAR( 10),
   @sValue       NVARCHAR( 20) = '0' OUTPUT  
) AS 
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cStorerSQL  NVARCHAR(MAX), 
           @cStorerSQL2 NVARCHAR(MAX), 
           @cStorerParm NVARCHAR(60), 
           @nSuccess    INT,
           @cSelect     NVARCHAR(MAX)  

   SET @cStorerParm = ''
   SELECT @cStorerParm = ISNULL(stsp.StorerKey,'') 
   FROM StockTakeSheetParameters stsp WITH (NOLOCK)
   WHERE stsp.StockTakeKey = @cCCRefNo
   
   SET @nSuccess = 1
   
   EXEC ispParseParameters  
      @c_Parameters = @cStorerParm, 
      @c_ColumnType = 'string', 
      @c_ColumnName = 'STORER.StorerKey',
      @c_Result1    = @cStorerSQL OUTPUT, 
      @c_Result2    = @cStorerSQL2 OUTPUT, 
      @n_Success     = @nSuccess OUTPUT 
        

   -- Storer level config
   IF ISNULL(@cStorerParm,'') <> ''
   BEGIN
      SET @cSelect = N'SELECT TOP 1 @sValue = StrCfg.SValue  ' +
         ' FROM rdt.StorerConfig StrCfg (NOLOCK) ' +
         ' JOIN  STORER WITH (NOLOCK) ON STORER.StorerKey = StrCfg.StorerKey ' +
         ' WHERE StrCfg.Function_ID = @nFunction_ID ' +  
         ' AND StrCfg.ConfigKey = @cConfigKey ' + 
         ISNULL(RTRIM(@cStorerSQL),'') + ISNULL(RTRIM(@cStorerSQL2),'') +
         ' ORDER BY StrCfg.sValue DESC ' 
      
      EXEC sp_ExecuteSQL @cSelect, 
           N'@nFunction_ID INT,  @cConfigKey NVARCHAR(30), @sValue NVARCHAR(30) OUTPUT ',
           @nFunction_ID,  @cConfigKey,  @sValue OUTPUT
    END 
           
   -- System level config
   IF ISNULL(@sValue,'') = ''
   BEGIN
      SELECT @sValue = NSQLValue
      FROM rdt.NSQLConfig (NOLOCK)
      WHERE Function_ID = @nFunction_ID
         AND ConfigKey = @cConfigKey   	
   END
         
   SET @sValue = IsNULL( @sValue, '0') 
END

GO