SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO




/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_SHIPPLABELDTC_GetParm                               */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2017-03-08 1.0  CSCHONG    Created                                         */     
/* 2017-04-19 1.1  CSCHONG    Fix sql recompile (CS01)                       */            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_SHIPPLABELDTC_GetParm]                      
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
   @b_debug             INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
   --SET ANSI_WARNINGS OFF              --CS01                
                              
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
      @c_condition3      NVARCHAR(150),
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
    SET @c_condition3= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    
    --SELECT DISTINCT @c_getUCCno = ISNULL(UccNo,'')
    --FROM UCC WITH (NOLOCK)
    --WHERE UccNo = @parm01
    --AND STATUS='1'
    
    --SELECT DISTINCT @c_getUdef09 = ISNULL(UccNo,'')
    --FROM UCC WITH (NOLOCK)
    --WHERE Userdefined09 = @parm01 
    
    IF ISNULL(@parm01,'') <>'' 
    BEGIN
    		IF ISNULL(@parm02,'') <>'' 
			BEGIN
			 SET @c_SQLJOIN = 'SELECT DISTINCT PARM1=''' + @parm01+ ''' ,PARM2=''' + @parm02+ ''',PARM3= ''' + @parm03 + ''' ,PARM4=''' + @parm04+ ''',PARM5=''' + @parm05+ ''',PARM6='''',PARM7='''', '+
									'PARM8='''',PARM9='''',PARM10='''',Key1=''DTC'',Key2=''' + @parm05+ ''',Key3='''',Key4='''','+
									' Key5='''' '  +  
									' FROM PICKDETAIL P (NOLOCK) JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = P.OrderKey '+  
									' WHERE lpd.LoadKey = ''' + @parm01 + ''' ' +
									 ' AND lpd.Orderkey = ''' + @parm02 + ''' '
		    END	
		    ELSE
		    BEGIN
		    	SET @c_SQLJOIN = 'SELECT DISTINCT PARM1=''' + @parm01+ ''' ,PARM2=''' + @parm02+ ''',PARM3= ''' + @parm03 + ''' ,PARM4=''' + @parm04+ ''',PARM5=''' + @parm05+ ''',PARM6='''',PARM7='''', '+
									'PARM8='''',PARM9='''',PARM10='''',Key1=''DTC'',Key2=''' + @parm05+ ''',Key3='''',Key4='''','+
									' Key5='''' '  +  
									' FROM PICKDETAIL P (NOLOCK) JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = P.OrderKey '+  
									' WHERE lpd.LoadKey = ''' + @parm01 + ''' '
		    END							 
    END
    ELSE
    BEGIN	
    IF ISNULL(@parm02,'') <>'' 
			BEGIN
			 SET @c_SQLJOIN = 'SELECT DISTINCT PARM1=''' + @parm01+ ''' ,PARM2=''' + @parm02+ ''',PARM3= ''' + @parm03 + ''' ,PARM4=''' + @parm04+ ''',PARM5=''' + @parm05+ ''',PARM6='''',PARM7='''', '+
									'PARM8='''',PARM9='''',PARM10='''',Key1=''DTC'',Key2=''' + @parm05+ ''',Key3='''',Key4='''','+
									' Key5='''' '  +  
									' FROM PICKDETAIL P (NOLOCK) JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = P.OrderKey '+  
									' WHERE lpd.Orderkey = ''' + @parm02 + ''' '
		    END		
    END
    
    	 IF ISNULL(@parm04,'')  <> ''
    	 BEGIN       
    	 	IF @c_SQLJOIN <> ''
    	 	 BEGIN
		       SET @c_condition1 = ' AND P.Caseid = ''' + @parm04 + ''' '
    	 	 END
    	 	 ELSE
    	 	 BEGIN
    	 	 	SET @c_SQLJOIN = 'SELECT DISTINCT PARM1=''' + @parm01+ ''' ,PARM2=''' + @parm02+ ''',PARM3= ''' + @parm03 + ''' ,PARM4=''' + @parm04+ ''',PARM5=''' + @parm05+ ''',PARM6='''',PARM7='''', '+
									'PARM8='''',PARM9='''',PARM10='''',Key1=''DTC'',Key2=''' + @parm05+ ''',Key3='''',Key4='''','+
									' Key5='''' '  +  
									' FROM PICKDETAIL P (NOLOCK) JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = P.OrderKey '+  
									' WHERE P.Caseid = ''' + @parm04 + ''' '
    	 	 END	
    	 END
    	 
    	 SET @c_SQL = @c_SQLJOIN + @c_condition1 
    	
    	 PRINT @c_SQL
    	
    EXEC sp_executesql @c_SQL    
            
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure



GO