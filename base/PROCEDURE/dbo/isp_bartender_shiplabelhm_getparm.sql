SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/******************************************************************************/                       
/* Copyright: IDS                                                             */                       
/* Purpose: isp_Bartender_ShiplabelHM_GetParm                                 */                       
/*                                                                            */                       
/* Modifications log:                                                         */                       
/*                                                                            */                       
/* Date       Rev  Author     Purposes                                        */                       
/* 2018-07-25 1.0  CHEEMUN    INC0334570 - HM Courier Label Sequence          */
/* 2018-08-23 1.1  CHEEMUN    INC0334570 - Cater for HM Label Qty=1&2         */    
/* 2018-10-08 1.2  CHEEMUN    INC0334570 - Order by logic same as DN          */                                   
/******************************************************************************/                      
                        
CREATE PROC [dbo].[isp_Bartender_ShiplabelHM_GetParm]                            
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
      @c_ReceiptKey        NVARCHAR(10),                          
      @c_ExternOrderKey  NVARCHAR(10),                    
      @c_Deliverydate    DATETIME,                    
      @n_intFlag         INT,           
      @n_CntRec          INT,          
      @c_SQL             NVARCHAR(4000),              
      @c_SQLSORT         NVARCHAR(4000),              
      @c_SQLJOIN         NVARCHAR(4000),      
      @c_condition1      NVARCHAR(150) ,      
      @c_condition2      NVARCHAR(150),      
      @c_SQLGroup        NVARCHAR(4000),      
      @c_SQLOrdBy        NVARCHAR(150)      
            
          
  DECLARE @d_Trace_StartTime   DATETIME,         
           @d_Trace_EndTime    DATETIME,        
           @c_Trace_ModuleName NVARCHAR(20),         
           @d_Trace_Step1      DATETIME,         
           @c_Trace_Step1      NVARCHAR(20),        
           @c_UserName         NVARCHAR(20),      
           @n_cntsku           INT,      
           @c_mode             NVARCHAR(1),      
           @c_sku              NVARCHAR(20),      
           @c_getUCCno         NVARCHAR(20),      
           @c_getUdef09        NVARCHAR(30)           
        
   SET @d_Trace_StartTime = GETDATE()        
   SET @c_Trace_ModuleName = ''        
              
    -- SET RowNo = 0                   
    SET @c_SQL = ''         
    SET @c_mode = '0'         
    SET @c_getUCCno = ''      
    SET @c_getUdef09 = ''        
    SET @c_SQLJOIN = ''              
    SET @c_condition1 = ''      
    SET @c_condition2= ''      
    SET @c_SQLOrdBy = ''      
    SET @c_SQLGroup = ''      
          
    
  IF ISNULL(@parm05,'') = '' AND  ISNULL(@parm06,'') = ''         
  BEGIN        
	IF ISNULL(@parm03,'') <>''       
    BEGIN      
    SET @c_SQLJOIN = 'SELECT PARM1=''' + @parm01+ ''' ,PARM2=P.OrderKey,PARM3= ''' + @parm03 + ''' ,PARM4=''' + @parm04+ ''',PARM5='''',PARM6='''',PARM7='''', '+      
         'PARM8='''',PARM9='''',PARM10='''',Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'',Key4=''YTO'','+      
       ' Key5=''' + @parm03+ ''' '  +        
       ' FROM   PICKDETAIL P (NOLOCK)     JOIN LOC l (NOLOCK) ON l.Loc = P.Loc '+        
       ' JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = P.OrderKey '+      
       ' JOIN Orders Ord (NOLOCK) ON Ord.loadkey=lpd.loadkey and Ord.orderkey=lpd.orderkey   '+      
       ' WHERE lpd.LoadKey = ''' + @parm01 + ''' '      
    END      
    ELSE      
    BEGIN      
     SET @c_SQLJOIN = 'SELECT PARM1=''' + @parm01+ ''' ,PARM2=P.OrderKey,PARM3= ''' + @parm03 + ''' ,PARM4=''' + @parm04+ ''',PARM5='''',PARM6='''',PARM7='''', '+      
         'PARM8='''',PARM9='''',PARM10='''',Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'',Key4=''YTO'','+      
       ' Key5=Ord.Shipperkey '  +        
       ' FROM   PICKDETAIL P (NOLOCK)     JOIN LOC l (NOLOCK) ON l.Loc = P.Loc '+        
       ' JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = P.OrderKey '+      
       ' JOIN Orders Ord (NOLOCK) ON Ord.loadkey=lpd.loadkey and Ord.orderkey=lpd.orderkey   '+      
       ' WHERE lpd.LoadKey = ''' + @parm01 + ''' '      
    END       
  END      
  ELSE      
  BEGIN      
    SET @c_SQLJOIN = 'SELECT PARM1=''' + @parm01+ ''' ,PARM2=P.OrderKey,PARM3= ''' + @parm03 + ''' ,PARM4=''' + @parm04+ ''',PARM5=''' + @parm05+ ''',PARM6=''' + @parm06+ ''',PARM7='''', '+      
         'PARM8='''',PARM9='''',PARM10='''',Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'',Key4=''YTO'','+      
       ' Key5=''' + @parm03+ ''' '  +            
       ' FROM PICKDETAIL P (NOLOCK) ' +      
       ' JOIN LOC l (NOLOCK) ON l.Loc = P.Loc '+        
       ' JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = P.OrderKey '+      
       ' JOIN Orders Ord (NOLOCK) ON Ord.loadkey=lpd.loadkey and Ord.orderkey=lpd.orderkey   '+      
       ' WHERE lpd.LoadKey = ''' + @parm01 + ''' '      
  END         
                      
  --INC0334570(START)              
  IF @parm04 = '1'  
  BEGIN              
   SET @c_SQLGroup = ' GROUP BY P.OrderKey,Ord.shipperkey ' +          
                     ' HAVING SUM(P.Qty) = 1 '          
   SET @c_SQLOrdBy = ' ORDER BY MIN(l.LogicalLocation), MIN(P.Loc), P.OrderKey   '                            
  END  
  IF @parm04 = '2'  
  BEGIN  
   SET @c_SQLGroup = ' GROUP BY P.OrderKey,Ord.shipperkey ' +    
                          ' HAVING SUM(P.Qty) >1 '    
   SET @c_SQLOrdBy = ' ORDER BY MAX(P.notes),P.OrderKey+MAX(P.Loc) '   
  END   
  --INC0334570(END)                       
     
  SET @c_SQL = @c_SQLJOIN + @c_condition1 + @c_condition2 + @c_SQLGroup + @c_SQLOrdBy      
           
  --PRINT @c_SQL      
           
  EXEC sp_executesql @c_SQL          
                  
   EXIT_SP:          
        
      SET @d_Trace_EndTime = GETDATE()        
      SET @c_UserName = SUSER_SNAME()        
                                       
END -- procedure        


GO