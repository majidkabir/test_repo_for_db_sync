SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_GIFTCDLBL_GetParm                                            */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2022-10-25 1.0  CSCHONG    Devops Scripts combine and Created(WMS-21012)   */                            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_GIFTCDLBL_GetParm]                      
(  @parm01            NVARCHAR(250),              
   @parm02            NVARCHAR(250),              
   @parm03            NVARCHAR(250),              
   @parm04            NVARCHAR(250),              
   @parm05            NVARCHAR(250),              
   @parm06            NVARCHAR(250),              
   @parm07            NVARCHAR(250),              
   @parm08            NVARCHAR(250),              
   @parm09            NVARCHAR(250),              
   @parm10            NVARCHAR(250),        
   @b_debug           INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
                              
   DECLARE                     
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_SQLinsert       NVARCHAR(4000) ,  
      @c_SQLSelect       NVARCHAR(4000)   
      
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_ExecStatements   NVARCHAR(4000),    
           @c_ExecArguments    NVARCHAR(4000) 
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''    
    SET @c_SQLJOIN = ''        
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    SET @c_ExecStatements = ''
    SET @c_ExecArguments = ''
    SET @c_SQLinsert = ''
    SET @c_SQLSelect = ''


    SET @c_SQL = ''

   
     SELECT DISTINCT PARM1=OH.OrderKey, PARM2=OH.StorerKey,PARM3= '' ,PARM4='',PARM5='',PARM6='',PARM7='', 
                     PARM8='',PARM9='',PARM10='',Key1='orderkey',Key2='',Key3='',Key4='', Key5='' 
                     FROM ORDERS OH WITH (NOLOCK) 
                     WHERE OH.OrderKey =@parm01 
          
            
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO