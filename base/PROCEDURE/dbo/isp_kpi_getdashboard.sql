SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/
/* Stored Procedure: isp_KPI_GetDashboard                               */
/* Creation Date: 2013-Oct-22                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver  Purposes                                   */ 
/* 15-Nov-2013  NJOW01  1.0  Fix to return non-primary widget KPI       */
/*                           record to dashbard widget                  */
/************************************************************************/
CREATE PROC [dbo].[isp_KPI_GetDashboard] (    
   @cStorerKey NVARCHAR(15) = 'ALL',    
   @cFacility  NVARCHAR(10) = 'ALL',    
   @cCategory  NVARCHAR(30) = '',     
   @cDashboard CHAR(1) = 'N'    
)     
AS    
BEGIN   
   SET NOCOUNT ON  
       
   DECLARE @t_Result TABLE (     
      SeqNo       INT IDENTITY(1,1),    
      KPICode     NVARCHAR(100),    
      KPIDesc     NVARCHAR(500),    
      KPIValue    VARCHAR(15),     
      Color       CHAR(1),    
      LastRun     DATETIME,     
      PrimaryFlag NVARCHAR(2),     
      KPI         INT )    
          
          
             
   DECLARE @cPrimaryWidgetFlag NVARCHAR(2)    
          ,@nKPI               INT     
          ,@cKPICode           NVARCHAR(100)    
          ,@cKPIDesc           NVARCHAR(500)    
          ,@cTypeOfSymbol      NVARCHAR(10)    
          ,@dValue             DECIMAL(10, 3)      
          ,@cColor             CHAR(1)    
          ,@nYlMin             INT    
          ,@nYlMax             INT    
          ,@cKPIValue          VARCHAR(10)    
          ,@dLastRun           DATETIME       
          ,@cGetStorerKey      NVARCHAR(15)   
          ,@cGetFacility       NVARCHAR(10)    
          ,@nComputeValue      INT  
                 
   IF ISNULL(RTRIM(@cCategory), '') = ''    
   BEGIN    
      SELECT '', ''     
   END    
   ELSE    
   BEGIN    
      DECLARE CUR_CheckUp_KPI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      SELECT cuk.PrimaryWidgetFlag, cuk.KPI, cuk.KPICode, cuk.[Description],     
             cuk.TypeOfSymbol, cuk.YlMin, cuk.YlMax        
      FROM CheckUpKPI cuk WITH (NOLOCK)     
      WHERE cuk.DisplayOnDashboard = CASE WHEN ISNUMERIC(@cDashboard) = '1' AND @cDashboard <> '' THEN @cDashboard ELSE cuk.DisplayOnDashboard END      
      AND   cuk.[Enabled] = 'Y'     
      AND   cuk.Category = @cCategory     
      --AND   cuk.PrimaryWidgetFlag = CASE WHEN ISNUMERIC(@cDashboard) = '1' AND @cDashboard <> '' THEN 'Y' ELSE cuk.PrimaryWidgetFlag END  --NJOW01
      ORDER BY CASE WHEN PrimaryWidgetFlag = 'Y' THEN 1 ELSE 9 END, cuk.KPI     
             
      OPEN CUR_CheckUp_KPI     
          
      FETCH NEXT FROM CUR_CheckUp_KPI INTO @cPrimaryWidgetFlag, @nKPI, @cKPICode, @cKPIDesc, @cTypeOfSymbol, @nYlMin, @nYlMax    
          
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         SET @dValue = 0    
  
             
         IF (SELECT CHARINDEX('@cStorerKey',[SQL]) FROM CheckUpKPI cuk WITH (NOLOCK) WHERE cuk.KPI = @nKPI) = 0 OR @cStorerKey = 'ALL'  
            SET @cGetStorerKey = ''  
         ELSE   
            SET @cGetStorerKey = @cStorerKey   
  
         IF (SELECT CHARINDEX('@cFacility',[SQL]) FROM CheckUpKPI cuk WITH (NOLOCK) WHERE cuk.KPI = @nKPI) = 0 OR @cFacility = 'ALL'   
            SET @cGetFacility = ''  
         ELSE   
            SET @cGetFacility = @cFacility   
  
--         IF @cGetStorerKey = '' AND @cGetFacility = ''  
--         BEGIN  
--            SELECT TOP 1 @dValue = cuk.[Value],     
--                         @dLastRun = cuk.RunDate     
--            FROM CheckUpKPIDetail cuk WITH (NOLOCK)     
--            WHERE cuk.KPI = @nKPI     
--            AND   cuk.StorerKey = ''   
--            AND   cuk.Facility  = ''    
--            ORDER BY KPIDet DESC                
--         END                          
--         ELSE  
--         BEGIN  
--  
--SELECT @cGetFacility '@cGetFacility', @cGetStorerKey '@cGetStorerKey', @nKPI '@nKPI'  
  
  
            SELECT TOP 1 @dValue = cuk.[Value],     
                         @dLastRun = cuk.RunDate     
            FROM CheckUpKPIDetail cuk WITH (NOLOCK)     
            WHERE cuk.KPI = @nKPI     
            AND   cuk.StorerKey = @cGetStorerKey    
            AND   cuk.Facility  = @cGetFacility      
            ORDER BY KPIDet DESC                
              
--         END                          
             
         -- SELECT @dValue, CAST( CONVERT(DECIMAL(3,1), @dValue) AS VARCHAR(5) )     
         IF @cTypeOfSymbol = '%'    
            SELECT @cKPIValue = CAST( CONVERT(DECIMAL(10,1), @dValue) AS VARCHAR(15) ) + '%'    
         ELSE     
         BEGIN  
             SET @cKPIValue = CAST(CONVERT(INT, @dValue) AS VARCHAR(10))   
--            SET @nComputeValue = @dValue  
--            SET @cKPIValue = ''  
--            WHILE @nComputeValue > 0   
--            BEGIN  
--               Set @cKPIValue = str(@nComputeValue % 1000, 3, 0) + Coalesce(','+@cKPIValue, '')  
--               Set @nComputeValue = @nComputeValue / 1000  
--            END  
--  
--            SET @cKPIValue =  SUBSTRING(@cKPIValue, 1, LEN(@cKPIValue) - 1)  
         END  
                
                
         SET @cColor = CASE WHEN @dValue < @nYlMin THEN 'R'     
                            WHEN @dValue > @nYlMax THEN 'G'    
                            ELSE 'Y'    
                       END     
             
         IF @dValue > 0     
         BEGIN    
            INSERT INTO @t_Result (KPICode, KPIDesc, KPIValue, Color, LastRun, PrimaryFlag, KPI)    
            VALUES (@cKPICode, @cKPIDesc, @cKPIValue, @cColor, @dLastRun, @cPrimaryWidgetFlag, @nKPI)                
         END     
             
         FETCH NEXT FROM CUR_CheckUp_KPI INTO @cPrimaryWidgetFlag, @nKPI, @cKPICode, @cKPIDesc, @cTypeOfSymbol, @nYlMin, @nYlMax    
      END    
      CLOSE CUR_CheckUp_KPI     
      DEALLOCATE CUR_CheckUp_KPI     
          
   END    
   SELECT * FROM @t_Result     
   ORDER BY SeqNo
END -- Procedure 

GO