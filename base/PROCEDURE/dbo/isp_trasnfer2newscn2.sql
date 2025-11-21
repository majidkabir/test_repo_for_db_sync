SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: isp_Trasnfer2NewScn2                                  */    
/* Creation Date: 16-Apr-2012                                              */    
/* Copyright: IDS                                                          */    
/* Written by: Chee Jun Yan                                                */    
/*                                                                         */    
/* Purpose: Convert from rdt.scn to rdt.scndetail                          */    
/*                                                                         */    
/*                                                                         */    
/* Input Parameters: Mobile No                                             */    
/*                                                                         */    
/* Output Parameters: NIL                                                  */    
/*                                                                         */    
/* Return Status:                                                          */    
/*                                                                         */    
/* Usage:                                                                  */    
/*                                                                         */    
/*                                                                         */    
/* Called By: isp_Trasnfer2NewScn                                          */    
/*                                                                         */    
/* PVCS Version: 1.0                                                       */    
/*                                                                         */    
/* Version: 5.4                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date         Ver. Author    Purposes                                    */    
/*                                                                         */     
/***************************************************************************/    
 

CREATE PROC [dbo].[isp_Trasnfer2NewScn2]   
(  
  @n_Scn INT,  
  @n_Func INT = 0 ,  
  @c_ConverAll NVARCHAR(50) = ''  
  
)  
AS  
BEGIN  
      
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
--DECLARE @Format  TABLE (  
--            [mobile] INT  
--           ,[typ] [NVARCHAR] (20) NULL DEFAULT ''  
--           ,[x] [NVARCHAR] (10) NULL DEFAULT ''  
--           ,[y] [NVARCHAR] (10) NULL DEFAULT ''  
--           ,[length] [NVARCHAR] (10) NULL DEFAULT ''  
--           ,[id] [NVARCHAR] (20) NULL DEFAULT ''  
--           ,[default] [NVARCHAR] (60) NULL DEFAULT ''  
--           ,[type] [NVARCHAR] (20) NULL DEFAULT ''  
--           ,[value] [NVARCHAR] (125) NULL DEFAULT ''  
--           ,[func]  [NVARCHAR] (4) NULL DEFAULT ''  
--        )  

-- (Chee01)
DECLARE @Format TABLE (  
     [mobile]  int,  
     [id]      [NVARCHAR] (20)   NULL DEFAULT '', 
     [x]       [NVARCHAR] (10)   NULL DEFAULT '',  
     [y]       [NVARCHAR] (10)   NULL DEFAULT '',  
	  [color]	[NVARCHAR] (20)   NULL DEFAULT '',
     [type]    [NVARCHAR] (20)   NULL DEFAULT '',  
	  [RegExp]  [NVARCHAR] (255)  NULL DEFAULT '',
	  [text]		[NVARCHAR] (20)   NULL DEFAULT '',
     [value]   [NVARCHAR] (50)   NULL DEFAULT '', 
     [length]  [NVARCHAR] (20)   NULL DEFAULT '',  
	  [lkupV]   [NVARCHAR] (4000) NULL DEFAULT '', 
     [func]    [NVARCHAR] (4)    NULL DEFAULT ''         
)  

  
DECLARE @cLine   NVARCHAR(125)  
       ,@nLine   INT  
       ,@cSQL    NVARCHAR(1000)  
       ,@y       NVARCHAR(10)  
       ,@scn     INT   
       ,@c_lang_code NVARCHAR(3)  
       ,@c_func  NVARCHAR(4)  
  
IF @c_ConverAll = 'ALL'  
BEGIN  
     
      DELETE rdt.RDTSCNDETAIL  
         
  
      DECLARE cur1  CURSOR LOCAL FAST_FORWARD READ_ONLY   
      FOR  
  
          SELECT r.scn, r.lang_code, r.func  
          FROM   rdt.RDTScn r  WITH (NOLOCK)
          Order by r.Scn  
  
  
     
END  
ELSE  
BEGIN  
   IF @n_Func = 0   
   BEGIN  
      DELETE rdt.RDTSCNDETAIL WHERE scn = @n_Scn  
         
  
      DECLARE cur1  CURSOR LOCAL FAST_FORWARD READ_ONLY   
      FOR  
  
          SELECT r.scn, r.lang_code, r.func  
          FROM   rdt.RDTScn r  WITH (NOLOCK)
          WHERE  r.Scn =@n_Scn  
          Order by r.Scn  
  
   END   
   ELSE   
   BEGIN  
      DELETE rdt.RDTSCNDETAIL WHERE func  = @n_Func  
         
  
      DECLARE cur1  CURSOR LOCAL FAST_FORWARD READ_ONLY   
      FOR  
  
          SELECT r.scn, r.lang_code, r.func  
          FROM   rdt.RDTScn r  WITH (NOLOCK)
          WHERE  r.Func =@n_Func  
          Order by r.Scn  
   END  
END  
    
OPEN cur1  
  
FETCH NEXT FROM cur1 INTO @scn, @c_lang_code, @c_func  
  
WHILE @@FETCH_STATUS<>-1  
BEGIN  
    --SELECT @scn '@scn'   
    DELETE FROM @Format   
    PRINT @scn  
      
    SELECT @nLine = 1  
      
    WHILE @nLine<=60  
    BEGIN  
        SELECT @cSQL = N'SELECT @cLine = Line'+RIGHT('0'+RTRIM(CAST(@nLine AS NVARCHAR(2))) ,2)   
              +  
               ' FROM RDT.RDTScn (NOLOCK) WHERE Scn = ' + CONVERT(NVARCHAR(10), @scn)    
          
        EXEC sp_executesql @cSQL  
            ,N'@cLine NVARCHAR(125) output'  
            ,@cLine OUTPUT  
          
        IF RTRIM(@cLine) IS NOT NULL  
           AND RTRIM(@cLine)<>''  
        BEGIN  
           
           PRINT @cLine  
                  
             
            SET @y = RIGHT('0'+RTRIM(CAST(@nLine AS CHAR(2))) ,2)  
              
--            INSERT INTO @Format  
--            EXEC isp_OldScn_to_NewScn   
--                 @y=@y  
--                ,@cMsg=@cLine  
--                ,@cDefaultFromCol='OUT'  
  
				-- (Chee01)
				INSERT INTO @Format
				EXEC isp_OldScn_to_NewScn2
                 @y=@y  
                ,@cMsg=@cLine  
                ,@cDefaultFromCol='OUT'                  

            -- SELECT * FROM @Format  
        END  
          
        SET @nLine = @nLine+1  
    END  
      
    IF NOT EXISTS(  
           SELECT 1  
           FROM   [RDT].[RDTSCNDETAIL]  WITH (NOLOCK)
           WHERE  scn = @scn  
       )  
    BEGIN  
--        INSERT INTO [RDT].[RDTSCNDETAIL]  
--          (  
--            [scn], [fieldno], [xcol], [yrow], [textcolor], [coltype],  
--            [coltext], [colvalue], [colvaluelength],[func],[lang_code]  
--          )  
--        SELECT @scn  
--              ,f.id  
--              ,f.x  
--              ,f.y  
--              ,'white'  
--              ,f.[typ]  
--              ,f.[value]  
--              ,''  
--              ,f.length  
--              ,@c_func  
--              ,@c_lang_code  
--        FROM   @Format f  

-- (Chee01)
INSERT INTO [RDT].[RDTSCNDETAIL]  
          (  
            [scn], [fieldno], [xcol], [yrow], [textcolor], [coltype], [ColRegExp], 
            [coltext], [colvalue], [colvaluelength], [ColLookUpView], [func],[lang_code]  
          )  
        SELECT @scn  
              ,f.[id]  
              ,f.[x]  
              ,f.[y]  
              ,f.[color]  
              ,f.[type]  
				  ,f.[RegExp]
              ,f.[text]  
              ,f.[value]
              ,f.[length]  
				  ,f.[lkupV]
              ,@c_func  
              ,@c_lang_code  
        FROM   @Format f
    END  
  
    FETCH NEXT FROM cur1 INTO @scn, @c_lang_code, @c_func  
END  
DEALLOCATE cur1  
  
END  -- Procedure

GO