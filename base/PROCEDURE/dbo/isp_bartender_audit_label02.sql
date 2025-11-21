SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

    
  /******************************************************************************/                     
/*                                                                            */                     
/* Purpose: isp_Bartender_Audit_Label01                                       */  
/* Generarte label info for Audit Labels                                      */                    
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */                     
/* 2024-08-26 1.0  Leonardo Aguilar Zarco    Created (LAZ013)                 */                     
/*																		      */ 
/*																		      */                     
/******************************************************************************/                    
                      
CREATE PROC [dbo].[isp_Bartender_Audit_Label02]                          
(  @c_Sparm01            NVARCHAR(250),                  
   @c_Sparm02            NVARCHAR(250),                  
   @c_Sparm03            NVARCHAR(250),                  
   @c_Sparm04            NVARCHAR(250),                  
   @c_Sparm05            NVARCHAR(250),                  
   @c_Sparm06            NVARCHAR(250),                  
   @c_Sparm07            NVARCHAR(250),                  
   @c_Sparm08            NVARCHAR(250),                  
   @c_Sparm09            NVARCHAR(250),                  
   @c_Sparm10            NVARCHAR(250),            
   @b_debug             INT = 0                             
)                          
AS                  
  


DECLARE    @CheckedBy              NVARCHAR(80)  
         , @SortedBy               NVARCHAR(80)  
         , @SKU                    NVARCHAR(80)  
         , @PackedQty              NVARCHAR(80)  
         , @CheckedQty             NVARCHAR(80)  
         , @Difference             NVARCHAR(80) 
		 -- Checked By
		 , @Col15                  NVARCHAR(80)  
		 , @Col16                  NVARCHAR(80)  
		 , @Col17                  NVARCHAR(80)  
		 , @Col18                  NVARCHAR(80)  
		 , @Col19                  NVARCHAR(80)  
		 --Sorted By
		 , @Col20                  NVARCHAR(80) 
		 , @Col21                  NVARCHAR(80)  
		 , @Col22                  NVARCHAR(80)  
		 , @Col23                  NVARCHAR(80)
		 , @Col24                  NVARCHAR(80)  
		 --Sku
		 , @Col25                  NVARCHAR(80)  
		 , @Col26                  NVARCHAR(80) 
		 , @Col27                  NVARCHAR(80)  
		 , @Col28                  NVARCHAR(80)  
		 , @Col29                  NVARCHAR(80) 
		 --Packed Qty
		 , @Col30                  NVARCHAR(80)  
		 , @Col31                  NVARCHAR(80)  
		 , @Col32                  NVARCHAR(80) 
		 , @Col33                  NVARCHAR(80) 
         , @Col34                  NVARCHAR(80) 
		--Checked Qty
		 , @Col35                  NVARCHAR(80)  
		 , @Col36                  NVARCHAR(80)  
		 , @Col37                  NVARCHAR(80) 
		 , @Col38                  NVARCHAR(80) 
         , @Col39                  NVARCHAR(80) 
		 --Difference
		 , @Col40                  NVARCHAR(80)  
		 , @Col41                  NVARCHAR(80)  
		 , @Col42                  NVARCHAR(80) 
		 , @Col43                  NVARCHAR(80) 
         , @Col44                  NVARCHAR(80) 
		 , @count_rows			   INT
		 , @id                     INT




  
BEGIN                          
  
   SET NOCOUNT ON                     
   SET ANSI_NULLS OFF                    
   SET QUOTED_IDENTIFIER OFF                     
   SET CONCAT_NULL_YIELDS_NULL OFF                    
   SET ANSI_WARNINGS OFF                          
  
--  set @c_Sparm01='CID0351227'
                                  
   DECLARE                      
      @c_ReceiptKey        NVARCHAR(10),                        
      @c_ExternOrderKey  NVARCHAR(10),                  
      @c_Deliverydate    DATETIME,                  
      @n_intFlag         INT,         
      @n_CntRec          INT,        
      @c_SQL             NVARCHAR(4000),            
      @c_SQLSORT         NVARCHAR(4000),            
      @c_SQLJOIN         NVARCHAR(4000)          
        
  DECLARE @d_Trace_StartTime   DATETIME,       
           @d_Trace_EndTime    DATETIME,      
           @c_Trace_ModuleName NVARCHAR(20),       
           @d_Trace_Step1      DATETIME,       
           @c_Trace_Step1      NVARCHAR(20),      
           @c_UserName         NVARCHAR(20)         
      
   SET @d_Trace_StartTime = GETDATE()      
   SET @c_Trace_ModuleName = ''      
            
    -- SET RowNo = 0                 
    SET @c_SQL = ''                    
                  
    CREATE TABLE [#Result] (                 
      [ID]    [INT] IDENTITY(1,1) NOT NULL,                                
      [Col01] [NVARCHAR] (80) NULL,                  
      [Col02] [NVARCHAR] (80) NULL,                  
      [Col03] [NVARCHAR] (80) NULL,                  
      [Col04] [NVARCHAR] (80) NULL,                  
      [Col05] [NVARCHAR] (80) NULL,                  
      [Col06] [NVARCHAR] (80) NULL,                  
      [Col07] [NVARCHAR] (80) NULL,                  
      [Col08] [NVARCHAR] (80) NULL,                  
      [Col09] [NVARCHAR] (80) NULL,                  
      [Col10] [NVARCHAR] (80) NULL,                  
      [Col11] [NVARCHAR] (80) NULL,                  
      [Col12] [NVARCHAR] (80) NULL,                  
      [Col13] [NVARCHAR] (80) NULL,                  
      [Col14] [NVARCHAR] (80) NULL,                  
      [Col15] [NVARCHAR] (80) NULL,                 
      [Col16] [NVARCHAR] (80) NULL,                  
      [Col17] [NVARCHAR] (80) NULL,                  
      [Col18] [NVARCHAR] (80) NULL,                  
      [Col19] [NVARCHAR] (80) NULL,                  
      [Col20] [NVARCHAR] (80) NULL,                  
      [Col21] [NVARCHAR] (80) NULL,                  
      [Col22] [NVARCHAR] (80) NULL,                  
      [Col23] [NVARCHAR] (80) NULL,                  
      [Col24] [NVARCHAR] (80) NULL,                  
      [Col25] [NVARCHAR] (80) NULL,                  
      [Col26] [NVARCHAR] (80) NULL,                  
      [Col27] [NVARCHAR] (80) NULL,                  
      [Col28] [NVARCHAR] (80) NULL,                  
      [Col29] [NVARCHAR] (80) NULL,                  
      [Col30] [NVARCHAR] (80) NULL,                  
      [Col31] [NVARCHAR] (80) NULL,                  
      [Col32] [NVARCHAR] (80) NULL,                  
      [Col33] [NVARCHAR] (80) NULL,                  
      [Col34] [NVARCHAR] (80) NULL,                  
      [Col35] [NVARCHAR] (80) NULL,                  
      [Col36] [NVARCHAR] (80) NULL,                  
      [Col37] [NVARCHAR] (80) NULL,                  
      [Col38] [NVARCHAR] (80) NULL,                  
      [Col39] [NVARCHAR] (80) NULL,                  
      [Col40] [NVARCHAR] (80) NULL,                  
      [Col41] [NVARCHAR] (80) NULL,                  
      [Col42] [NVARCHAR] (80) NULL,                  
      [Col43] [NVARCHAR] (80) NULL,                  
      [Col44] [NVARCHAR] (80) NULL,                  
      [Col45] [NVARCHAR] (80) NULL,                  
      [Col46] [NVARCHAR] (80) NULL,                  
      [Col47] [NVARCHAR] (80) NULL,                  
      [Col48] [NVARCHAR] (80) NULL,                  
      [Col49] [NVARCHAR] (80) NULL,                  
      [Col50] [NVARCHAR] (80) NULL,                 
      [Col51] [NVARCHAR] (80) NULL,                  
      [Col52] [NVARCHAR] (80) NULL,                  
      [Col53] [NVARCHAR] (80) NULL,                  
      [Col54] [NVARCHAR] (80) NULL,                  
      [Col55] [NVARCHAR] (80) NULL,                  
      [Col56] [NVARCHAR] (80) NULL,                  
      [Col57] [NVARCHAR] (80) NULL,                  
      [Col58] [NVARCHAR] (80) NULL,                  
      [Col59] [NVARCHAR] (80) NULL,                  
      [Col60] [NVARCHAR] (80) NULL                 
     )                
   ---HEADER
   SET @c_SQLJOIN = ' SELECT DISTINCT top 1 ''PPA''+ RIGHT(a.DeviceID,2) PPA,convert(varchar,b.AddDate,120) [Check Date],convert(varchar,d.DeliveryDate,120) [Delivery Date],b.UserName [Check by] ,c.CaseID [Case ID] ,' + CHAR(13)  --5   --WL01
                  + ' c.WaveKey,c.OrderKey ,' + CHAR(13)  --7
				  + ' '''','''','''','''','''','''','''','''',' --15    
				  + ' '''','''','''','''','''','         --20        
                  + ' '''','''','''','''','''','''','''','''','''','''','  --30    
                  + ' '''','''','''','''','''','''','''','''','''','''','   --40         
                  + ' '''','''','''','''','''','''','''','''','''','''', '  --50         
                  + ' '''','''','''','''','''','''','''','''','''','''' '   --60            
             + CHAR(13) +              
             
                  + ' FROM PTL.PTLTRAN a WITH (NOLOCK), rdt.RDTPPA b WITH (NOLOCK),PICKDETAIL c(NOLOCK),Orders d(NOLOCK) ' + CHAR(13)
                  + ' WHERE a.CaseID=b.DropID ' + CHAR(13)
                  + ' AND a.StorerKey=b.StorerKey AND a.CaseID=c.DropID AND b.DropID=c.DropID ' + CHAR(13)
				  + ' AND a.SKU=b.Sku AND b.Sku=c.Sku AND a.SKU= c.Sku ' + CHAR(13)
				  + ' AND a.StorerKey=c.Storerkey AND b.StorerKey=c.Storerkey ' + CHAR(13)
				  + ' AND a.OrderKey=d.OrderKey AND c.OrderKey=d.OrderKey  ' + CHAR(13)
				  + ' AND b.DropID=  ''' + @c_Sparm01 + ''' '



      
    IF @b_debug=1            
    BEGIN            
      PRINT @c_SQLJOIN              
    END                    
                  
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +               
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +             
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +               
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +               
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +               
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '              
        
   SET @c_SQL = @c_SQL + @c_SQLJOIN      
    
        
            
   EXEC sp_executesql @c_SQL              
            
   IF @b_debug=1            
   BEGIN              
      PRINT @c_SQL              
   END       
    
   update #Result    
   SET col12 =  @c_Sparm03,    
       col13 =  @c_Sparm04        
	   
	---DETAIL---


SET ROWCOUNT 5	
	SELECT IDENTITY(int, 1,1) AS ID_Num,UserName [Checked By],AddWho [Sorted By],b.sku SKU,PQty [Packed Qty],CQty [Checked Qty],PQty-CQty Difference, 0 as procesado
	   INTO #tmp_label_detail
	     FROM PTL.PTLTRAN a WITH(NOLOCK) , rdt.RDTPPA b WITH(NOLOCK)
	    WHERE a.CaseID= b.DropID
	         and a.SKU=b.Sku
	         and b.DropID=@c_Sparm01
	GROUP BY  UserName ,AddWho ,b.sku ,PQty,CQty ,PQty-CQty 
SET ROWCOUNT 0

Set @count_rows= @@ROWCOUNT

WHILE(SELECT count(1) FROM #tmp_label_detail WHERE procesado=0 ) > '0'
BEGIN

		set rowcount 1         
		select @id=ID_Num,@CheckedBy=[Checked By],@SortedBy=[Sorted By],@SKU=SKU,@PackedQty=[Packed Qty],@CheckedQty=[Checked Qty],@Difference=Difference 
		from  #tmp_label_detail where procesado= 0
		set rowcount 0


		IF @id= 1
		Begin
				 Set @Col15 =   @CheckedBy
				 Set @Col16 =   @SortedBy
				 Set @Col17 =   @SKU
				 Set @Col18 =   @PackedQty
				 Set @Col19 =   @CheckedQty
				 Set @Col20 =   @Difference
		End		 

		IF @id= 2
		Begin	 
				 Set @Col21 =   @CheckedBy
				 Set @Col22 =   @SortedBy
				 Set @Col23 =   @SKU
				 Set @Col24 =   @PackedQty
				 Set @Col25 =   @CheckedQty
				 Set @Col26 =   @Difference
		End		 

		IF @id= 3
		Begin
				 Set @Col27 =   @CheckedBy
				 Set @Col28 =   @SortedBy
				 Set @Col29 =   @SKU
				 Set @Col30 =   @PackedQty
				 Set @Col31 =   @CheckedQty
				 Set @Col32 =   @Difference
		End		 
		 
		IF @id= 4
		Begin
				 Set @Col33 =   @CheckedBy
				 Set @Col34 =   @SortedBy
				 Set @Col35 =   @SKU
				 Set @Col36 =   @PackedQty
				 Set @Col37 =   @CheckedQty
				 Set @Col38 =   @Difference
		End		 

		IF @id= 5
		Begin
				 Set @Col39 =   @CheckedBy
				 Set @Col40 =   @SortedBy
				 Set @Col41 =   @SKU
				 Set @Col42 =   @PackedQty
				 Set @Col43 =   @CheckedQty
				 Set @Col44 =   @Difference
		End		 
		 			 	
		update #tmp_label_detail set procesado=1 where ID_Num=@id

				set @id=null
				set @CheckedBy=null
				set @SortedBy= null
				set @SKU=null
				set @PackedQty=null
				set @CheckedQty=null
				set @Difference=null 

END

update #Result set 
Col15=@Col15,
Col16=@Col16,
Col17=@Col17,
Col18=@Col18,
Col19=@Col19,
Col20=@Col20,
Col21=@Col21,
Col22=@Col22,
Col23=@Col23,
Col24=@Col24,
Col25=@Col25,
Col26=@Col26,
Col27=@Col27,
Col28=@Col28,
Col29=@Col29,
Col30=@Col30,
Col31=@Col31,
Col32=@Col32,
Col33=@Col33,
Col34=@Col34,
Col35=@Col35,
Col36=@Col36,
Col37=@Col37,
Col38=@Col38,
Col39=@Col39,
Col40=@Col40,
Col41=@Col41,
Col42=@Col42,
Col43=@Col43,
Col44=@Col44
	
         
   IF @b_debug=1            
   BEGIN            
     SELECT * FROM #Result (nolock)            
   END            
          
  SELECT * FROM #Result (nolock)            
                
   EXIT_SP:        
      
      SET @d_Trace_EndTime = GETDATE()      
      SET @c_UserName = SUSER_SNAME()      
         
      EXEC isp_InsertTraceInfo       
         @c_TraceCode = 'BARTENDER',      
         @c_TraceName = 'isp_Bartender_Audit_Label02',      
         @c_starttime = @d_Trace_StartTime,      
         @c_endtime = @d_Trace_EndTime,      
         @c_step1 = @c_UserName,      
         @c_step2 = '',      
         @c_step3 = '',      
         @c_step4 = '',      
         @c_step5 = '',      
         @c_col1 = @c_Sparm01,       
         @c_col2 = @c_Sparm02,      
         @c_col3 = @c_Sparm03,      
         @c_col4 = @c_Sparm04,      
         @c_col5 = @c_Sparm05,      
         @b_Success = 1,      
         @n_Err = 0,      
         @c_ErrMsg = ''                  
       
      
                                      
   END -- procedure       
    
  

GO