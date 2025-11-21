SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/               
/* Copyright: LFL                                                             */               
/* Purpose: BarTender Filter by ShipperKey                                    */  
/*          Copy from: isp_BT_Bartender_HK_WWMTLabel_LULU                     */                           
/*                                                                            */               
/* Modifications log:                                                         */               
/*                                                                            */               
/* Date       Rev  Author     Purposes                                        */               
/* 2021-01-18 1.0  WLChooi    Created (WMS-15926)                             */ 
/* 2021-01-22 1.1  WLChooi    Fix Col59 (WL01)                                */
/******************************************************************************/              
                
CREATE PROC [dbo].[isp_BT_Bartender_CN_WWMTLabel_LULU]                     
(  @c_Sparm1            NVARCHAR(250),            
   @c_Sparm2            NVARCHAR(250),            
   @c_Sparm3            NVARCHAR(250),            
   @c_Sparm4            NVARCHAR(250),            
   @c_Sparm5            NVARCHAR(250),            
   @c_Sparm6            NVARCHAR(250),            
   @c_Sparm7            NVARCHAR(250),            
   @c_Sparm8            NVARCHAR(250),            
   @c_Sparm9            NVARCHAR(250),            
   @c_Sparm10           NVARCHAR(250),      
   @b_debug             INT = 0                       
)                    
AS                    
BEGIN                    
   SET NOCOUNT ON               
   SET ANSI_NULLS OFF              
   SET QUOTED_IDENTIFIER OFF               
   SET CONCAT_NULL_YIELDS_NULL OFF              
   --SET ANSI_WARNINGS OFF       
                            
   DECLARE                    
      @c_SQL             NVARCHAR(4000),            
      @c_SQLJOIN         NVARCHAR(4000)   
   

  DECLARE @d_Trace_StartTime   DATETIME, 
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20), 
           @d_Trace_Step1      DATETIME, 
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @n_copy             INT ,
           @c_DelimiterSign    NVARCHAR(1),
           @c_seqno            NVARCHAR(5),
           @c_DataField        NVARCHAR(MAX),
           @c_TableName        NVARCHAR (50),
           @c_Key1             NVARCHAR (80),
           @c_Key2             NVARCHAR (80),  
           @c_Key3             NVARCHAR (80),  
           @c_Storerkey        NVARCHAR (20),
           @c_ColValue         NVARCHAR(MAX) ,
           @n_SeqNo            INT,
           @c_style            NVARCHAR(20),
           @c_sku              NVARCHAR(20),
           @c_SCData           NVARCHAR(30),
           @c_SCType           NVARCHAR(50),
           @c_altsku           NVARCHAR(20),
           @n_Unitprice        FLOAT

  DECLARE @c_field01          NVARCHAR(80),
          @c_field02          NVARCHAR(80),
          @c_field03          NVARCHAR(80),
          @c_field04          NVARCHAR(80),
          @c_field05          NVARCHAR(80),
          @c_field06          NVARCHAR(80),
          @c_field07          NVARCHAR(80),
          @c_field08          NVARCHAR(80),
          @c_field09          NVARCHAR(80),
          @c_field10          NVARCHAR(80),  
          @c_field11          NVARCHAR(80),
          @c_field12          NVARCHAR(80),
          @c_field13          NVARCHAR(80),
          @c_field14          NVARCHAR(80),
          @c_field15          NVARCHAR(80),
          @c_field16          NVARCHAR(80),
          @c_field17          NVARCHAR(80),
          @c_field18          NVARCHAR(80),
          @c_field19          NVARCHAR(80),
          @c_field20          NVARCHAR(80),  
          @c_field21          NVARCHAR(80),
          @c_field22          NVARCHAR(80),
          @c_field23          NVARCHAR(80),
          @c_field24          NVARCHAR(80),
          @c_field25          NVARCHAR(80),
          @c_field26          NVARCHAR(80),
          @c_field27          NVARCHAR(80),
          @c_field28          NVARCHAR(80),
          @c_field29          NVARCHAR(80),
          @c_field30          NVARCHAR(80),   
          @c_field31          NVARCHAR(80),
          @c_field32          NVARCHAR(80),
          @c_field33          NVARCHAR(80),
          @c_field34          NVARCHAR(80),
          @c_field35          NVARCHAR(80),
          @c_field36          NVARCHAR(80),
          @c_field37          NVARCHAR(80),
          @c_field38          NVARCHAR(80),
          @c_field39          NVARCHAR(80),
          @c_field40          NVARCHAR(80),    
          @c_field41          NVARCHAR(80),
          @c_field42          NVARCHAR(80),
          @c_field43          NVARCHAR(80),
          @c_field44          NVARCHAR(80),
          @c_field45          NVARCHAR(80),
          @c_field46          NVARCHAR(80),
          @c_field47          NVARCHAR(80),
          @c_field48          NVARCHAR(80),
          @c_field49          NVARCHAR(80),
          @c_field50          NVARCHAR(80), 
          @c_field51          NVARCHAR(80),
          @c_field52          NVARCHAR(80),
          @c_field53          NVARCHAR(80),
          @c_field54          NVARCHAR(80)
         

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''
      
   -- SET RowNo = 0           
   SET @c_SQL = ''      
    
   SET @n_copy = CONVERT(INT,@c_Sparm3)
   SET @c_DelimiterSign = '|'
   SET @c_style = ''

   SET @c_field01=''
   SET @c_field02=''
   SET @c_field03=''
   SET @c_field04=''
   SET @c_field05=''
   SET @c_field06=''
   SET @c_field07=''
   SET @c_field08=''
   SET @c_field09=''
   SET @c_field10=''
   SET @c_field11=''
   SET @c_field12=''
   SET @c_field13=''
   SET @c_field14=''
   SET @c_field15=''
   SET @c_field16=''
   SET @c_field17=''
   SET @c_field18=''
   SET @c_field19=''
   SET @c_field20=''
   SET @c_field21=''
   SET @c_field22=''
   SET @c_field23=''
   SET @c_field24=''
   SET @c_field25=''
   SET @c_field26=''
   SET @c_field27=''
   SET @c_field28=''
   SET @c_field29=''
   SET @c_field30=''
   SET @c_field31=''
   SET @c_field32=''
   SET @c_field33=''
   SET @c_field34=''
   SET @c_field35=''
   SET @c_field36=''
   SET @c_field37=''
   SET @c_field38=''
   SET @c_field39=''
   SET @c_field40=''
   SET @c_field41=''
   SET @c_field42=''
   SET @c_field43=''
   SET @c_field44=''
   SET @c_field45=''
   SET @c_field46=''
   SET @c_field47=''
   SET @c_field48=''
   SET @c_field49=''
   SET @c_field50=''
   SET @c_field51=''
   SET @c_field52=''
   SET @c_field53=''
   SET @c_field54=''
        
            
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

   CREATE TABLE [#Tempdocinfo] (
      [RowID]         [INT] IDENTITY(1,1) NOT NULL,   
      [TableName]     [NVARCHAR] (20) NULL,
      [Key1]          [NVARCHAR] (20) NULL,
      [Key2]          [NVARCHAR] (20) NULL ,  
      [Key3]          [NVARCHAR] (20) NULL ,  
      [Storerkey]     [NVARCHAR] (15) NULL,  
      [Field01]       [NVARCHAR] (80) NULL, 
      [Field02]       [NVARCHAR] (80) NULL,
      [Field03]       [NVARCHAR] (80) NULL,
      [Field04]       [NVARCHAR] (80) NULL, 
      [Field05]       [NVARCHAR] (80) NULL, 
      [Field06]       [NVARCHAR] (80) NULL, 
      [Field07]       [NVARCHAR] (80) NULL, 
      [Field08]       [NVARCHAR] (80) NULL,
      [Field09]       [NVARCHAR] (80) NULL, 
      [Field10]       [NVARCHAR] (80) NULL, 
      [Field11]       [NVARCHAR] (80) NULL, 
      [Field12]       [NVARCHAR] (80) NULL, 
      [Field13]       [NVARCHAR] (80) NULL, 
      [Field14]       [NVARCHAR] (80) NULL, 
      [Field15]       [NVARCHAR] (80) NULL, 
      [Field16]       [NVARCHAR] (80) NULL, 
      [Field17]       [NVARCHAR] (80) NULL, 
      [Field18]       [NVARCHAR] (80) NULL, 
      [Field19]       [NVARCHAR] (80) NULL, 
      [Field20]       [NVARCHAR] (80) NULL, 
      [Field21]       [NVARCHAR] (80) NULL, 
      [Field22]       [NVARCHAR] (80) NULL, 
      [Field23]       [NVARCHAR] (80) NULL, 
      [Field24]       [NVARCHAR] (80) NULL, 
      [Field25]       [NVARCHAR] (80) NULL, 
      [Field26]       [NVARCHAR] (80) NULL, 
      [Field27]       [NVARCHAR] (80) NULL, 
      [Field28]       [NVARCHAR] (80) NULL, 
      [Field29]       [NVARCHAR] (80) NULL, 
      [Field30]       [NVARCHAR] (80) NULL, 
      [Field31]       [NVARCHAR] (80) NULL, 
      [Field32]       [NVARCHAR] (80) NULL, 
      [Field33]       [NVARCHAR] (80) NULL, 
      [Field34]       [NVARCHAR] (80) NULL, 
      [Field35]       [NVARCHAR] (80) NULL, 
      [Field36]       [NVARCHAR] (80) NULL, 
      [Field37]       [NVARCHAR] (80) NULL, 
      [Field38]       [NVARCHAR] (80) NULL, 
      [Field39]       [NVARCHAR] (80) NULL, 
      [Field40]       [NVARCHAR] (80) NULL, 
      [Field41]       [NVARCHAR] (80) NULL, 
      [Field42]       [NVARCHAR] (80) NULL, 
      [Field43]       [NVARCHAR] (80) NULL, 
      [Field44]       [NVARCHAR] (80) NULL,
      [Field45]       [NVARCHAR] (80) NULL, 
      [Field46]       [NVARCHAR] (80) NULL,
      [Field47]       [NVARCHAR] (80) NULL, 
      [Field48]       [NVARCHAR] (80) NULL, 
      [Field49]       [NVARCHAR] (80) NULL, 
      [Field50]       [NVARCHAR] (80) NULL, 
      [Field51]       [NVARCHAR] (80) NULL, 
      [Field52]       [NVARCHAR] (80) NULL, 
      [Field53]       [NVARCHAR] (80) NULL, 
      [Field54]       [NVARCHAR] (80) NULL 
   )  
      
   SET @c_DataField = ''
   SET @c_key2 = ''
   SET @c_style = ''
   SET @c_sku = ''
   SET @c_SCData = ''
  
  
   SELECT TOP 1 @c_style = S.style
   FROM SKU s (NOLOCK)
   WHERE s.ALTSKU = @c_Sparm2
   AND s.StorerKey = @c_Sparm4
  
  
   SELECT @c_sku = Pd.sku
         ,@c_altsku = s.altsku
   FROM PackDetail AS pd WITH (NOLOCK)
   JOIN SKU S WITH (NOLOCK) ON s.sku=pd.sku AND s.StorerKey=pd.StorerKey
   WHERE s.ALTSKU=@c_Sparm2
   AND s.StorerKey = @c_Sparm4
  
   IF ISNULL(@c_sku,'') = ''
   BEGIN
      SELECT TOP 1 @c_sku = s.SKU
                  ,@c_altsku = s.altsku
      FROM SKU s (NOLOCK)
      WHERE s.ALTSKU=@c_Sparm2
      AND s.StorerKey = @c_Sparm4
   END
  
   SELECT @c_SCData = LTRIM(RTRIM(ISNULL(SC.Data,'')))
        , @c_SCType = LTRIM(RTRIM(ISNULL(SC.ConfigType,'')))
   FROM SKUCONFIG SC (NOLOCK)
   WHERE SC.SKU=@c_sku
   AND SC.Storerkey=@c_Sparm4
   AND SC.Userdefine01=@c_Sparm1
  
   SELECT @c_key2 = C.code2
   FROM CODELKUP AS c WITH (NOLOCK)
   WHERE c.LISTNAME='LULUWWMT'
   AND c.code=@c_Sparm1
   
   SELECT  @c_DataField = DATA
   FROM DOCINFO (NOLOCK)
   WHERE TableName='SKU'
   AND Key1  = @c_style
   AND Key2 = @c_key2
   AND StorerKey = @c_Sparm4

   SET @n_Unitprice = 0.00   
   
   IF ISNULL(@c_Sparm5,'') <> '' AND EXISTS (SELECT 1 FROM ORDERDETAIL WITH (NOLOCK) WHERE Orderkey = @c_Sparm5)
   BEGIN
      SELECT @n_Unitprice = MAX(OD.Unitprice)
      FROM  ORDERDETAIL OD WITH (NOLOCK) 
      WHERE OD.Orderkey = @c_Sparm5
   END
 
   DECLARE C_DelimSplit CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SeqNo, ColValue 
   FROM dbo.fnc_DelimSplit(@c_DelimiterSign,@c_DataField)
   
   OPEN C_DelimSplit
   FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue

   WHILE (@@FETCH_STATUS=0) 
   BEGIN   
         
      IF @n_SeqNo = 1 
      BEGIN
         SET @c_field01=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 2
      BEGIN
         SET @c_field02=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 3
      BEGIN
         SET @c_field03=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 4
      BEGIN
         SET @c_field04=CONVERT(NVARCHAR(80),@c_ColValue)
      END   
      ELSE IF @n_SeqNo = 5
      BEGIN
         SET @c_field05=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 6
      BEGIN
         SET @c_field06=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 7
      BEGIN
         SET @c_field07=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 8
      BEGIN
         SET @c_field08=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 9
      BEGIN
         SET @c_field09=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 10
      BEGIN
         SET @c_field10=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 11
      BEGIN
         SET @c_field11=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 12
      BEGIN
         SET @c_field12=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 13
      BEGIN
         SET @c_field13=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 14
      BEGIN
         SET @c_field14=CONVERT(NVARCHAR(80),@c_ColValue)
      END   
      ELSE IF @n_SeqNo = 15
      BEGIN
         SET @c_field15=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 16
      BEGIN
         SET @c_field16=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 17
      BEGIN
         SET @c_field17=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 18
      BEGIN
         SET @c_field18=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 19
      BEGIN
         SET @c_field19=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 20
      BEGIN
         SET @c_field20=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 21
      BEGIN
         SET @c_field21=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 22
      BEGIN
         SET @c_field22=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 23
      BEGIN
         SET @c_field23=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 24
      BEGIN
         SET @c_field24=CONVERT(NVARCHAR(80),@c_ColValue)
      END   
      ELSE IF @n_SeqNo = 25
      BEGIN
         SET @c_field25=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 26
      BEGIN
         SET @c_field26=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 27
      BEGIN
         SET @c_field27=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 28
      BEGIN
         SET @c_field28=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 29
      BEGIN
         SET @c_field29=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 30
      BEGIN
         SET @c_field30=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 31
      BEGIN
         SET @c_field31=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 32
      BEGIN
         SET @c_field32=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 33
      BEGIN
         SET @c_field33=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 34
      BEGIN
         SET @c_field34=CONVERT(NVARCHAR(80),@c_ColValue)
      END   
      ELSE IF @n_SeqNo = 35
      BEGIN
         SET @c_field35=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 36
      BEGIN
         SET @c_field36=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 37
      BEGIN
         SET @c_field37=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 38
      BEGIN
         SET @c_field38=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 39
      BEGIN
         SET @c_field39=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 40
      BEGIN
         SET @c_field40=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 41
      BEGIN
         SET @c_field41=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 42
      BEGIN
         SET @c_field42=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 43
      BEGIN
         SET @c_field43=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 44
      BEGIN
         SET @c_field44=CONVERT(NVARCHAR(80),@c_ColValue)
      END   
      ELSE IF @n_SeqNo = 45
      BEGIN
         SET @c_field45=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 46
      BEGIN
         SET @c_field46=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 47
      BEGIN
         SET @c_field47=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 48
      BEGIN
         SET @c_field48=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 49
      BEGIN
         SET @c_field49=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 50
      BEGIN
         SET @c_field50=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 51
      BEGIN
         SET @c_field51=CONVERT(NVARCHAR(80),@c_ColValue)
      END
      ELSE IF @n_SeqNo = 52
      BEGIN
         SET @c_field52=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 53
      BEGIN
         SET @c_field53=CONVERT(NVARCHAR(80),@c_ColValue)
      END 
      ELSE IF @n_SeqNo = 54
      BEGIN
         SET @c_field54=CONVERT(NVARCHAR(80),@c_ColValue)
      END
            
      FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue
   END 

   CLOSE C_DelimSplit
   DEALLOCATE C_DelimSplit                 
            
   INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09       
                       ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22        
                       ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34        
                       ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44      
                       ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54    
                       ,Col55,Col56,Col57,Col58,Col59,Col60) 
             
   VALUES (@c_field02,@c_field03,@c_field04,@c_field06,@c_field07,@c_field08,@c_field09,@c_field10,@c_field11,@c_field12    --10
          ,@c_field13,@c_field14,@c_field15,@c_field16,@c_field17,@c_field18,@c_field19,@c_field20,@c_field21,@c_field22
          ,@c_field23,@c_field24,@c_field25,@c_field26,@c_field27,@c_field28,@c_field29,@c_field30,@c_field31,@c_field32
          ,@c_field33,@c_field34,@c_field35,@c_field36,@c_field37,@c_field38,@c_field39,@c_field40,@c_field41,@c_field42
          ,@c_field43,@c_field44,@c_field45,@c_field46,@c_field47,@c_field48,@c_field49,@c_field50,@c_field51,@c_field52
          ,@c_field53,@c_field54,@c_style,@c_Sparm1,@c_SCData,@c_altsku,@c_sku,@n_Unitprice
          --,CASE WHEN @c_SCType = 'CNY' THEN N'â”¬Ã‘' ELSE @c_SCType END + ' ' + @c_SCData,'')   --WL01
          ,@c_SCData,'')   --WL01

   WHILE @n_copy > 1
   BEGIN   
   
      INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09           
                          ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22         
                          ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34           
                          ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44           
                          ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54           
                          ,Col55,Col56,Col57,Col58,Col59,Col60)
      SELECT Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09          
            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22         
            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34           
            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44           
            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54           
            ,Col55,Col56,Col57,Col58,Col59,Col60
      FROM #RESULT
      WHERE ID = 1
   
      SET @n_copy = @n_copy - 1
   END     
      
   IF @b_debug=1      
   BEGIN        
      PRINT @c_SQL        
   END      
   IF @b_debug=1      
   BEGIN      
     SELECT * FROM #Result (nolock)      
   END     

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()
   
   EXEC isp_InsertTraceInfo 
      @c_TraceCode = 'BARTENDER',
      @c_TraceName = 'isp_BT_Bartender_CN_WWMTLabel_LULU',
      @c_starttime = @d_Trace_StartTime,
      @c_endtime = @d_Trace_EndTime,
      @c_step1 = @c_UserName,
      @c_step2 = '',
      @c_step3 = '',
      @c_step4 = '',
      @c_step5 = '',
      @c_col1 = @c_Sparm1, 
      @c_col2 = @c_Sparm2,
      @c_col3 = @c_Sparm3,
      @c_col4 = @c_Sparm4,
      @c_col5 = @c_Sparm5,
      @b_Success = 1,
      @n_Err = 0,
      @c_ErrMsg = ''            
 
   select * from #result WITH (NOLOCK)
                                
END -- procedure

GO