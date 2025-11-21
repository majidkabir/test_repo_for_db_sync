SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_BT_Bartender_TW_ECStore_ship_Label_01                         */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2017-07-20 1.0  CSCHONG    Created (WMS-5561)                              */ 
/* 2019-11-21 1.1  CSCHONG    WMS-11119 add new field (CS01)                  */
/* 2022-05-06 1.2  WLChooi    WMS-19590 - Add/modify columns (WL01)           */
/* 2023-01-04 1.3  Mingle     WMS-21422 - Add Col35 (ML01)                    */
/* 2023-03-20 1.4  WLChooi    WMS-22033 - Modify Col21 (WL02)                 */
/* 2023-03-20 1.4  WLChooi    DevOps Combine Script                           */
/******************************************************************************/                
CREATE   PROC [dbo].[isp_BT_Bartender_TW_ECStore_ship_Label_01]                      
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
   @b_debug              INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                                      
                              
   DECLARE                  
      @c_Uccno           NVARCHAR(20),                    
      @c_Sku             NVARCHAR(20),                         
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @n_totalcase       INT,
      @n_sequence        INT,
      @c_skugroup        NVARCHAR(10),
      @n_CntSku          INT,
      @n_TTLQty          INT      
    
  DECLARE @d_Trace_StartTime  DATETIME,   
          @d_Trace_EndTime    DATETIME,  
          @c_Trace_ModuleName NVARCHAR(20),   
          @d_Trace_Step1      DATETIME,   
          @c_Trace_Step1      NVARCHAR(20),  
          @c_UserName         NVARCHAR(20)
           
   DECLARE @c_ExecStatements     NVARCHAR(4000)  
         , @c_ExecArguments      NVARCHAR(4000)  
         , @c_ExecStatements2    NVARCHAR(4000)  
         , @c_ExecStatementsAll  NVARCHAR(MAX)    
         , @n_continue           INT  
			, @c_Col35					NVARCHAR(60)
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
   -- SET RowNo = 0             
   SET @c_SQL = ''  
   SET @c_Sku = '' 
   SET @c_skugroup = ''    
   SET @n_totalcase = 0  
   SET @n_sequence  = 1 
   SET @n_CntSku = 1  
   SET @n_TTLQty = 0     
              
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
                     
  SET @c_SQLJOIN = +N' SELECT DISTINCT ISNULL(o.M_contact1,''''),ISNULL(o.C_contact1,''''),ISNULL(o.M_contact2,''''),ISNULL(o.m_company,''''),'  + CHAR(13) +      --4
             + ' ISNULL(O.MarkForKey,''''),ISNULL(O.TrackingNo,''''),ISNULL(o.M_address1,'''')'+ CHAR(13) + 
             + ' ,ISNULL(o.M_address2,''''),ISNULL(o.M_address3,''''),'+ CHAR(13) + 
             + ' ISNULL(ORDIF.StoreName,''''), '   + CHAR(13) +   --10   --WL01
             + ' ISNULL(o.M_address4,''''),ISNULL(o.M_phone1,''''),' + CHAR(13) +  --12      
             + ' ISNULL(o.M_Fax1,''''),ISNULL(o.M_Fax2,''''),ORDIF.DeliveryCategory, '  + CHAR(13) +  --15    --CS01
             + ' ORDIF.OrderInfo08,ORDIF.OrderInfo09,o.m_vat,substring(ORDIF.notes,1,80),ORDIF.OrderInfo10,'     + CHAR(13) +  --20          --CS01             
         --    + CHAR(13) +      
             + ' o.route,o.m_zip,o.m_country,ORDIF.OrderInfo07,ORDIF.OrderInfo03,o.c_phone1,ORDIF.Platform,'+ CHAR(13) +
             + ' substring(ORDIF.notes,81,80),substring(ORDIF.notes,161,80), ISNULL(o.BuyerPO,''''),'  + CHAR(13) + --30    --CS01   --WL01
             + ' ISNULL(ORDIF.EcomOrderId,''''),ISNULL(CL1.Description,''''),ISNULL(CL1.Long,''''),ISNULL(CL1.Notes,''''),'''','''','''','''','''','''','  + CHAR(13) +  --40   --WL01       
             + ' '''','''','''','''','''','''','''','''','''','''', ' + CHAR(13) +  --50       
             + ' '''','''','''','''','''','''','''','''','''','''' '   + CHAR(13) + --60          
           --  + CHAR(13) +            
             + ' FROM PackHeader AS ph WITH (NOLOCK)'   + CHAR(13) +     
             + ' JOIN PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo'   + CHAR(13) + 
             + ' JOIN ORDERS AS o WITH (NOLOCK) ON o.OrderKey = ph.OrderKey '   + CHAR(13) +  
             + ' LEFT JOIN Storer ST WITH (NOLOCK) ON ST.storerkey=o.storerkey '   + CHAR(13) +            
             + ' LEFT JOIN ORDERINFO ORDIF WITH (NOLOCK) ON ORDIF.orderkey=O.orderkey '   + CHAR(13) +   
             + ' LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.Listname = ''WebsitInfo'' AND CL1.Code = ORDIF.StoreName AND CL1.Storerkey = O.Storerkey ' + CHAR(13) +    --WL01 
             + ' WHERE pd.pickslipno = @c_Sparm01 '   + CHAR(13) + 
             + ' AND pd.labelno = @c_Sparm02 '    + CHAR(13) + 
             + ' GROUP BY ISNULL(o.M_contact1,''''),ISNULL(o.C_contact1,''''),ISNULL(o.M_contact2,''''),ISNULL(o.m_company,''''),ISNULL(O.MarkForKey,''''),'+ CHAR(13) + 
             + ' ISNULL(O.TrackingNo,''''),ISNULL(o.M_address1,''''),ISNULL(o.M_address2,''''),ISNULL(o.M_address3,''''),' + CHAR(13) +   
             + ' ISNULL(ORDIF.StoreName,''''),ISNULL(o.M_address4,''''),ISNULL(o.M_phone1,''''),ISNULL(o.M_Fax1,''''),ISNULL(o.M_Fax2,''''),' +CHAR(13) +
             + ' ORDIF.DeliveryCategory,ORDIF.OrderInfo08,ORDIF.OrderInfo09,o.m_vat,ORDIF.notes,ORDIF.OrderInfo10,ORDIF.OrderInfo07,ORDIF.OrderInfo03,'  + CHAR(13) +   --CS01
             + ' o.route,ORDIF.Platform,o.m_zip,o.m_country,o.c_phone1, ISNULL(o.BuyerPO,''''), ISNULL(ORDIF.EcomOrderId,''''), '   --CS01   --WL01
             + ' ISNULL(ORDIF.StoreName,''''),ISNULL(CL1.Description,''''),ISNULL(CL1.Long,''''),ISNULL(CL1.Notes,'''') '   --WL01
          
   IF @b_debug=1        
   BEGIN        
      SELECT @c_SQLJOIN          
   END                
              
   SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
   --SET @c_SQL = @c_SQL + @c_SQLJOIN   
   SET @c_ExecStatements = @c_SQL + CHAR(13) + @c_SQLJOIN 
       
   IF @b_debug=1        
   BEGIN        
      SELECT @c_ExecStatements          
   END  
       
   SET @c_ExecArguments = N' @c_Sparm01    NVARCHAR(60)'  
                        +  ',@c_Sparm02    NVARCHAR(60)'  
                                     
  
   EXEC sp_ExecuteSql @c_ExecStatements   
                    , @c_ExecArguments  
                    , @c_Sparm01  
                    , @c_Sparm02  
  
   IF @@ERROR <> 0       
   BEGIN  
      SET @n_continue = 3  
      ROLLBACK TRAN  
      GOTO QUIT  
   END       
        
   --EXEC sp_executesql @c_SQL          
        
   IF @b_debug=1        
   BEGIN          
      PRINT @c_SQL          
   END        

   --START ML01
   SELECT TOP 1 @c_Col35 = refno2
   FROM PACKDETAIL(NOLOCK)
   WHERE PICKSLIPNO = @c_Sparm01	

   UPDATE #Result  
   SET Col35 = @c_Col35 
   --END ML01

   --WL02 S
   IF EXISTS ( SELECT 1
               FROM PACKHEADER PH (NOLOCK)
               JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.Orderkey
               WHERE PH.PickSlipNo = @c_Sparm01
               AND OH.Shipperkey = '91Family' )
   BEGIN
      UPDATE #Result
      SET Col21 = CASE WHEN Col21 IN ('1','01') THEN N'北'
                       WHEN Col21 IN ('2','02') THEN N'中'
                       WHEN Col21 IN ('3','03') THEN N'南'
                       ELSE Col21 END
   END
   --WL02 E

   IF @b_debug=1        
   BEGIN        
      SELECT * FROM #Result (nolock)        
   END 
            
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_TW_ECStore_ship_Label_01',  
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
   
   SELECT * FROM #Result (nolock) 
   
   QUIT: 
                                  
END -- procedure   

GO