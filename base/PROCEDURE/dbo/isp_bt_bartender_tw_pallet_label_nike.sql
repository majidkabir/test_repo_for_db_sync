SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
  
/******************************************************************************/                         
/* Copyright: IDS                                                             */                         
/* Purpose: BarTender Filter by ShipperKey                                    */                         
/*                                                                            */                         
/* Modifications log:                                                         */                         
/*                                                                            */                         
/* Date       Rev  Author     Purposes                                        */                         
/* 2014-10-17 1.0  CSCHONG    Created (SOS323111)                             */  
/* 2014-11-06 2.0  CSCHONG     Add new mapping for Col23 (CS01)               */     
/* 2014-11-10 3.0  CSCHONG     Group by UCC.ID (CS02)                         */ 
/* 2014-11-13 4.0  CSCHONG     Change to count distinct UCC (CS03)            */ 
/* 2014-11-19 5.0  CSCHONG     Add Receiptkey as param3 (CS04)                */  
/* 2016-03-08 5.1  CSCHONG     Remove parm04 value to blank (CS05)            */  
/* 2016-04-20 5.2  CSCHONG     Bugs fix for 2nd page item no update (CS06)    */   
/* 2017-04-17 5.3  CSCHONG     Fix sql recompile (CS07)                       */ 
/******************************************************************************/                        
                          
CREATE PROC [dbo].[isp_BT_Bartender_TW_Pallet_Label_NIKE]                               
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
   --SET ANSI_WARNINGS OFF                   --(CS07)                   
                                      
   DECLARE            
      @c_Receiptdate       NVARCHAR(10),                        
      @C_RUserDefine05     NVARCHAR(50),          
      @C_RECEIPTKEY        NVARCHAR(11),          
      @C_UCCUserdefined01  NVARCHAR(15), 
      @n_TTLSKUCNT         INT,
      @n_TTLSKUQTY         INT, 
      @n_Page              INT,
      @n_ID                INT, 
      @n_GetRowID          INT, 
      @n_RID               INT, 
      @n_MaxLine           INT,       
      @n_MaxLineRec        INT, 
      @C_ToCity          NVARCHAR(45),          
      @C_ToCountry       NVARCHAR(30),          
      @c_FromCompany     NVARCHAR(30),                        
      @C_FromAddress     NVARCHAR(200),          
      @C_FromState       NVARCHAR(45),          
      @C_FromZip         NVARCHAR(18),          
      @C_FromCity        NVARCHAR(45),          
      @C_FromCountry     NVARCHAR(30),          
      @c_ToCompany1      NVARCHAR(30),                        
      @C_ToAddress1      NVARCHAR(200),          
      @C_ToState1        NVARCHAR(45),          
      @C_ToZip1          NVARCHAR(18),          
      @C_ToCity1         NVARCHAR(45),          
      @C_ToCountry1      NVARCHAR(30),          
      @c_FromCompany1    NVARCHAR(30),                        
      @C_FromAddress1    NVARCHAR(200),          
      @C_FromState1      NVARCHAR(45),          
      @C_FromZip1        NVARCHAR(18),          
      @C_FromCity1       NVARCHAR(45),          
      @C_FromCountry1    NVARCHAR(30),          
      @c_OrderKey        NVARCHAR(10),                            
      @c_ExternOrderKey  NVARCHAR(10),                      
      @c_Deliverydate    DATETIME,                      
      @c_caseid          NVARCHAR(20),           
      @c_ORDUDef10       NCHAR(2),          
      @c_ORDUDef04       NVARCHAR(20),          
      @c_ORDUDef04_1     NVARCHAR(20),          
      @c_wavekey         NVARCHAR(10)  
  
 Declare          
      @c_wavekey1        NVARCHAR(10),          
      @c_CaseID1         NVARCHAR(20),          
      @c_ODUDEF01        NVARCHAR(20),          
      @c_ODUDEF02        NVARCHAR(20),          
      @c_Carton          NVARCHAR(10),          
      @c_CodelShort      NVARCHAR(10),          
      @c_ODUDEF01_1      NVARCHAR(20),          
      @c_ODUDEF02_1      NVARCHAR(20),          
      @c_Carton1         NVARCHAR(10),          
      @c_CodelShort1     NVARCHAR(10),            
      @c_Style           NVARCHAR(20),           
      @n_intFlag         INT,             
      @n_CntRec          INT,          
      @c_colNo           NVARCHAR(5),          
      @c_colContent01    NVARCHAR(80),           
      @c_colContent02    NVARCHAR(80),            
      @c_colContent03    NVARCHAR(80),          
      @c_colContent04    NVARCHAR(80),          
      @c_colContent05    NVARCHAR(80),          
      @c_colContent06    NVARCHAR(80),          
      @c_colContent07    NVARCHAR(80),          
      @c_colContent08    NVARCHAR(80),          
      @c_colContent09    NVARCHAR(80),          
      @c_colContent10    NVARCHAR(80),          
      @c_ColContent      NVARCHAR(80),          
      @n_cntsku          INT,          
      @c_skuMeasurement  NVARCHAR(5),          
      @c_Company         NVARCHAR(45),                      
      @C_Address1        NVARCHAR(45),                      
      @C_Address2        NVARCHAR(45),                      
      @C_Address3        NVARCHAR(45),                      
      @C_Address4        NVARCHAR(45),                      
      @C_BuyerPO         NVARCHAR(20),                      
      @C_notes2          NVARCHAR(4000),                      
      @c_OrderLineNo     NVARCHAR(5),                      
      @c_SKU             NVARCHAR(20),                      
      @n_Qty             INT,                      
      @c_PackKey         NVARCHAR(10),                      
      @c_UOM             NVARCHAR(10),                      
      @C_PHeaderKey      NVARCHAR(18),                      
      @C_SODestination   NVARCHAR(30),                    
      @n_RowNo           INT,                    
      @n_SumPickDETQTY   INT,                    
      @n_SumUnitPrice    INT,                  
      @c_SQL             NVARCHAR(4000),                
      @c_SQLSORT         NVARCHAR(4000),                
      @c_SQLJOIN         NVARCHAR(4000),              
      @c_Udef04          NVARCHAR(80),                     
      @n_TTLPickQTY      INT,            
      @c_ShipperKey      NVARCHAR(15),          
               
      @n_TTLpage         INT,          
      @n_CurrentPage     INT,   
      @n_GetCurrentPage  INT,       
      @c_dropid          NVARCHAR(20),          
               
      @n_TTLLine         INT,          
      @n_TTLQty          INT,        
      @c_OrdUdef03       NCHAR(2),        
      @c_itemclass       NCHAR(4),        
      @c_skuGrp          NCHAR(5),        
      @c_SkuStyle        NCHAR(5),  
      @c_colContent11    NVARCHAR(80),           
      @c_colContent12    NVARCHAR(80),         
      @c_colContent13    NVARCHAR(80),        
      @c_colContent14    NVARCHAR(80),      
      @c_colContent15    NVARCHAR(80),            
      @c_colContent16    NVARCHAR(80),                
      @n_cntOrdUDef04    INT,               
      @c_getOrdUdef04    NVARCHAR(80),
      @n_CntTTLUCC       INT            --(CS03)       
          
  DECLARE  @d_Trace_StartTime   DATETIME,           
           @d_Trace_EndTime    DATETIME,          
           @c_Trace_ModuleName NVARCHAR(20),           
           @d_Trace_Step1      DATETIME,           
           @c_Trace_Step1      NVARCHAR(20),          
           @c_UserName         NVARCHAR(20),
           @c_Uccid            NVARCHAR(18)        --(CS02)             
          
   SET @d_Trace_StartTime = GETDATE()          
   SET @c_Trace_ModuleName = ''          
                
    -- SET RowNo = 0                     
    SET @c_SQL = ''                
    SET @n_SumPickDETQTY = 0                    
    SET @n_SumUnitPrice = 0                    
                      
--    IF OBJECT_ID('tempdb..#Result','u') IS NOT NULL        
--      DROP TABLE #Result;        
          
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
          
--      IF OBJECT_ID('tempdb..#CartonContent','u') IS NOT NULL        
--      DROP TABLE #CartonContent;        
        
     CREATE TABLE [#CartonContent] (                     
      [ID]                    [INT] IDENTITY(1,1) NOT NULL,
      [PageNum]               [INT]           NULL,
      [ExternKey]             [NVARCHAR] (20)  NULL,
      [UCCUserdefined01]      [NVARCHAR] (15) NULL,  
      [Material]              [NVARCHAR] (10) NULL,                                    
      [Size]                  [NVARCHAR] (10) NULL,                                 
      [skucnt]                INT NULL,             
      [skuqty]                INT NULL, 
      [UCCID]                 NVARCHAR(18) NULL,                --(CS02)                         
      [Retrieve]              [NVARCHAR] (1) default 'N')               
                    
                           
      IF @b_debug=1                
      BEGIN                  
        PRINT 'start'                  
      END          
          
    DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
          
    SELECT DISTINCT CONVERT(NVARCHAR(10),REC.RECEIPTDATE,111),REC.UserDefine05,REC.RECEIPTKEY,
    '',UCC.ID--,Substring(UCC.SKU,1,6)+ '-' + Substring(UCC.SKU,7,3)--,Substring(ucc.sku,10,5)  --(CS01)  --(CS05)
    FROM RECEIPT REC WITH (NOLOCK)
    JOIN RECEIPTDETAIL RECDET WITH (NOLOCK) ON REC.RECEIPTKEY = RECDET.RECEIPTKEY
    JOIN UCC WITH (NOLOCK) ON UCC.EXTERNKEY=RECDET.EXTERNRECEIPTKEY
    WHERE UCC.Id = @c_Sparm1 --and UCC.Userdefined01 = @c_Sparm2
    AND REC.RECEIPTKEY=CASE WHEN ISNULL(@c_Sparm3,'') <> '' THEN @c_Sparm3 ELSE REC.RECEIPTKEY END -- and userdefined01=@c_Sparm2       
    
          
   OPEN CUR_StartRecLoop                    
               
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_Receiptdate,@C_RUserDefine05,@C_RECEIPTKEY,@C_UCCUserdefined01,@c_UccID       
                                                       
                 
   WHILE @@FETCH_STATUS <> -1                    
   BEGIN           
          
      IF @b_debug=1                
      BEGIN                  
        PRINT 'Cur start'                  
      END          
          
   INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                            ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                            ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                            ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                            ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                            ,Col55,Col56,Col57,Col58,Col59,Col60)             
     VALUES(@c_Receiptdate,@C_RUserDefine05,@C_RECEIPTKEY,'','','','',          
            '','','','','','',          
            '','','','','','','',           
            '','',@c_Sparm1,'','','','','','','','','','','','','','','','','','','','','','','','','','',''        --(CS01)   
            ,'','','','','','','','','','O')          
          
          
   IF @b_debug=1                
   BEGIN                
     SELECT * FROM #Result (nolock)                
   END           
          
   SET @n_MaxLine    = 8
   SET @n_MaxLineRec = 9
   SET @n_TTLpage = 1           
   SET @n_CurrentPage = 1  
   SET @n_GetCurrentPage = 1        
   SET @n_intFlag = 1          
   SET @n_TTLLIne = 0          
   SET @n_TTLQty = 0          
            
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                      
                     
   SELECT DISTINCT id,col03--,col04        
   FROM #Result                 
   --WHERE Col60 = 'O' 
   ORDER BY ID          
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @n_RID,@C_RECEIPTKEY--,@C_UCCUserdefined01   --(CS05)
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                   
--      IF @b_debug='1'                
--      BEGIN                
--         PRINT @c_caseid                   
--      END                
      --  SELECT @n_SumPICKDETQty = SUM(QTY)                    
      --  FROM PICKDETAIL PD (NOLOCK)                    
      --   WHERE PD.OrderKey=@c_OrderKey                    
   --SET @n_intFlag = 1          
              
   INSERT INTO #CartonContent (Externkey,Material,[Size],skucnt,Skuqty,UCCID)      --(CS02)                    
   SELECT externkey,Substring(UCC.SKU,1,6)+ '-' + Substring(UCC.SKU,7,3),Substring(UCC.SKU,10,5),count(1),sum(qty),UCC.ID
     FROM UCC WITH (NOLOCK)
     WHERE UCC.Externkey IN (SELECT DISTINCT RECDET.Externreceiptkey 
                              FROM RECEIPTDETAIL RECDET WITH (NOLOCK)
                              WHERE RECDET.receiptkey=@C_RECEIPTKEY )
     --and ucc.userdefined01=@C_UCCUserdefined01                --(CS05)
     and ucc.id=@c_Uccid                                        --(CS02)
     and ucc.receiptkey = @C_RECEIPTKEY
     GROUP BY Externkey,ucc.SKU,UCC.ID            --(CS02)
     ORDER BY Substring(UCC.SKU,1,6)+ '-' + Substring(UCC.SKU,7,3)
     --ORDER BY CASE WHEN ISNUMERIC(ucc.sku) = 0 THEN Substring(ucc.sku,10,5) END desc,
     --             CONVERT(decimal(5,1), CASE WHEN ISNUMERIC(ucc.sku) = 1 THEN Substring(ucc.sku,10,5) ELSE '0.0' END)         
                           
       IF @b_debug = '1'              
       BEGIN              
         SELECT 'carton',* FROM #CartonContent          
       END              
            
     SET @c_colno=''                      
     SET @c_colContent01 = ''          
     SET @c_colContent02 = ''          
     SET @c_colContent03 = ''          
     SET @c_colContent04 = ''          
     SET @c_colContent05 = ''          
     SET @c_colContent06 = ''          
     SET @c_colContent07 = ''          
     SET @c_colContent08 = ''          
     SET @c_colContent09 = ''          
     SET @c_colContent10 = ''   
     SET @c_colContent11 = ''     
     SET @c_colContent12 = ''         
     SET @c_colContent13 = ''       
     SET @c_colContent14 = ''          
     SET @c_colContent15 = ''   
     SET @c_colContent16 = ''       
               
     SELECT @n_CntRec = count(1)           
     FROM #CartonContent          
     --WHERE Retrieve = 'N'  
     
             
         
    SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END 

    
   DECLARE CUR_UpdatePageNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT ID
   FROM #CartonContent AS cc
   ORDER BY cc.ID
   
   OPEN CUR_UpdatePageNo                    
               
   FETCH NEXT FROM CUR_UpdatePageNo INTO @n_GetRowID
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN                  
      	
    
		UPDATE #CartonContent
		SET PageNum = @n_GetCurrentPage --Floor(id % @n_MaxLine) +  (id % @n_MaxLine)
		WHERE ID= @n_GetRowID
   --SET PageNum = (CASE WHEN Floor(id % @n_MaxLine) = 0 THEN Floor(id/@n_MaxLineRec) + 1 ELSE Floor(id/@n_MaxLineRec) END) --+ (CASE WHEN id % @n_MaxLine = 0 THEN 1 ELSE 0 END)  
   
     IF (@n_GetRowID%@n_MaxLine) = 0
		BEGIN
   		SET @n_GetCurrentPage = @n_GetCurrentPage + 1
		END
   
     FETCH NEXT FROM CUR_UpdatePageNo INTO @n_GetRowID  
     END -- While                     
     CLOSE CUR_UpdatePageNo                    
     DEALLOCATE CUR_UpdatePageNo   
     
    IF @b_debug='1'          
    BEGIN          
       PRINT ' Rec Count : ' + convert(nvarchar(15),@n_CntRec)          
       PRINT ' TTL Page NO : ' + convert(nvarchar(15),@n_TTLpage)          
       PRINT ' Current Page NO : ' + convert(nvarchar(15),@n_CurrentPage)   
       SELECT * FROM  #CartonContent     
    END 
    
    --WHILE (@n_intFlag <=@n_MaxLine)          
    -- WHILE (@n_CurrentPage<=@n_TTLpage)             
   --  BEGIN          
                 
     --WHILE (@n_intFlag <=@n_MaxLine) 
     
     /*CS06 Start*/  
     
    
   WHILE (@n_CurrentPage < = @n_TTLpage)
   BEGIN

   SET @n_CurrentPage = @n_CurrentPage + 1  
       
        
       PRINT 'current page : ' + convert(nvarchar(5),@n_CurrentPage) + ' with Total Page ' +  convert(nvarchar(5),@n_TTLpage)  
       
       WHILE (@n_CurrentPage>@n_TTLpage)          
       BREAK;  
        
         IF @n_CurrentPage<=@n_TTLpage
          BEGIN
             IF NOT EXISTS (SELECT * FROM #RESULT WHERE ID = @n_CurrentPage)  
             BEGIN 
             INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09                   
                                  ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22                 
                                  ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34                  
                                  ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44                   
                                  ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54                 
                                  ,Col55,Col56,Col57,Col58,Col59,Col60)          
              VALUES(@c_Receiptdate,@C_RUserDefine05,@C_RECEIPTKEY,'','','','',          
                  '','','','','','',          
                  '','','','','','','',           
                  '','',@c_Sparm1,'','','','','','','','','','','','','','','','','','','','','','','','','','',''      --(CS02)     
                  ,'','','','','','','','','','N')   

             END            
          END
     END  
/*CS06 Start*/  
   
   DECLARE CUR_RowPage CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT ID,PageNum
   FROM #CartonContent
   --Where UCC.ID = @c_uccid
   Order by ID

   OPEN CUR_RowPage            
            
   FETCH NEXT FROM CUR_RowPage INTO  @n_ID,@n_page       
               
   WHILE @@FETCH_STATUS <> -1             
   BEGIN                 
      IF @b_debug='1'              
      BEGIN              
         PRINT convert(nvarchar(5),@n_page)                
      END

    -- BEGIN         
       IF @b_debug = '1'              
       BEGIN             
         SELECT * FROM  #CartonContent  WITH (NOLOCK)  WHERE Retrieve='N'         
         PRINT ' update for column no : ' + @c_Colno + 'with ID ' + convert(nvarchar(2),@n_id)          
       END       
      
  IF (@n_ID%@n_MaxLine) = 1
   BEGIN     
     SET @c_Colcontent = '' 
     SET @c_colContent01 = ''          
     SET @c_colContent02 = ''          
     SET @c_colContent03 = ''          
     SET @c_colContent04 = ''          
     SET @c_colContent05 = ''          
     SET @c_colContent06 = ''          
     SET @c_colContent07 = ''          
     SET @c_colContent08 = ''          
     SET @c_colContent09 = ''          
     --SET @c_colContent10 = ''   
     --SET @c_colContent11 = ''     
     --SET @c_colContent12 = ''         
     --SET @c_colContent13 = ''       
     --SET @c_colContent14 = ''          
     --SET @c_colContent15 = ''   
     --SET @c_colContent16 = '' 
   END
        
   SET @n_TTLLine = 0          
   SET @n_Qty = 0       
                 

      SELECT @c_Colcontent = case when material = '' then space(4) ELSE cast(material as nchar(10)) + space(5) END        
                           + case when [size] = '' then space(4) ELSE cast([size] as nchar(10)) + space(2) END        
                           + convert(nchar(5),skucnt)   + space(2)         
                           + convert(nchar(5),skuqty)                
       FROM  #CartonContent c WITH (NOLOCK)                      
       WHERE c.ID = @n_ID 
       AND c.PageNum = @n_Page
       --AND UCC.ID = @c_uccid         
        
            

     IF @b_debug='1'          
     BEGIN         
        PRINT 'check 1 ' +  substring(@c_Colcontent,1,4)        
        PRINT 'check 2 ' +  substring(@c_Colcontent,5,4)        
        PRINT 'check 3 ' +  substring(@c_Colcontent,9,6)        
        PRINT 'check 4 ' +  substring(@c_Colcontent,15,7)        
        PRINT 'check 5 ' +  substring(@c_Colcontent,22,7)        
        PRINT 'check 6 ' +  right(@c_Colcontent,5)        
        PRINT 'Udef10 : ' +  @c_OrdUdef10 + '03: ' + @c_OrdUdef03+ ' class ' + @c_itemclass + 'grp : ' + @c_skuGrp+ 'style:' +@c_SkuStyle+ 'qty : ' + convert(nchar(5),@n_TTLPickQTY)        
        PRINT 'Content : ' + @c_Colcontent + 'with lenght : ' + convert(nvarchar(3),LEN(@c_Colcontent))                 
     END  
     
     IF @b_debug='2'
     BEGIN
     	PRINT 'Content : ' + @c_Colcontent + 'with lenght : ' + convert(nvarchar(3),LEN(@c_Colcontent))   
     	PRINT 'ID: ' + convert(nvarchar(5),@n_ID) + ' line no : ' + CONVERT(nvarchar(5),@n_ID%@n_MaxLine)
     END        
          
       --IF @n_intFlag = 1 or @n_intFlag = 16 or @n_intFlag = 31 or @n_intFlag = 46 --(CS04)         
       IF (@n_ID%@n_MaxLine) = 1   
       BEGIN          
        SET @c_colContent01 = @c_Colcontent          
       END          
        
       --ELSE IF @n_intFlag = 2 OR @n_intFlag = 17 OR @n_intFlag = 32 OR @n_intFlag = 47  --(CS04)       
       ELSE IF (@n_ID%@n_MaxLine) = 2  
       BEGIN          
        SET @c_colContent02 = @c_Colcontent          
       END          
        
       --ELSE IF @n_intFlag = 3 OR @n_intFlag = 18 OR @n_intFlag = 33 OR @n_intFlag = 48    --(CS04)       
       ELSE IF (@n_ID%@n_MaxLine) = 3  
       BEGIN              
        SET @c_colContent03 = @c_Colcontent          
       END          
        
       --ELSE IF @n_intFlag = 4 OR @n_intFlag = 19 OR @n_intFlag = 34 OR @n_intFlag = 49 --(CS04)          
       ELSE IF (@n_ID%@n_MaxLine) = 4  
       BEGIN          
        SET @c_colContent04 = @c_Colcontent          
       END          
        
      -- ELSE IF @n_intFlag = 5 OR @n_intFlag = 20 OR @n_intFlag = 35  OR @n_intFlag = 50 --(CS04)          
       ELSE IF (@n_ID%@n_MaxLine) = 5  
       BEGIN          
        SET @c_colContent05 = @c_Colcontent          
       END          
        
       --ELSE IF @n_intFlag = 6 OR @n_intFlag = 21 OR @n_intFlag = 36  OR @n_intFlag = 51  --(CS04)         
       ELSE IF (@n_ID%@n_MaxLine) = 6  
       BEGIN          
        SET @c_colContent06 = @c_Colcontent          
       END          
               
       --ELSE IF @n_intFlag = 7 OR @n_intFlag = 22 OR @n_intFlag = 37 OR @n_intFlag = 52  --(CS04)          
       ELSE IF (@n_ID%@n_MaxLine) = 7  
       BEGIN          
        SET @c_colContent07 = @c_Colcontent          
       END          
        
       --ELSE IF @n_intFlag = 8 OR @n_intFlag = 23 OR @n_intFlag = 38 OR @n_intFlag = 53  --(CS04)          
       ELSE IF (@n_ID%@n_MaxLine) = 8  
       BEGIN          
        SET @c_colContent08 = @c_Colcontent          
       END          
        
       --ELSE IF @n_intFlag = 9 OR @n_intFlag = 24 OR @n_intFlag = 39 OR @n_intFlag = 54  --(CS04)          
       ELSE IF (@n_ID%@n_MaxLine) = 9  
       BEGIN          
        SET @c_colContent09 = @c_Colcontent          
       END  
          
       --ELSE IF @n_intFlag = 10 OR @n_intFlag = 25 OR @n_intFlag = 40  OR @n_intFlag = 55  --(CS04)         
       --ELSE IF (@n_ID%@n_MaxLine) = 10  
       --BEGIN          
       -- SET @c_colContent10 = @c_Colcontent          
       --END   
  
       --/*CS04 Start*/         
       ----ELSE IF @n_intFlag = 11 OR @n_intFlag = 26 OR @n_intFlag = 41 OR @n_intFlag = 56         
       --ELSE IF (@n_ID%@n_MaxLine) = 11  
       --BEGIN          
       -- SET @c_colContent11 = @c_Colcontent          
       --END   
  
       ----ELSE IF @n_intFlag = 12 OR @n_intFlag = 27 OR @n_intFlag = 42  OR @n_intFlag = 57         
       --ELSE IF (@n_ID%@n_MaxLine) = 12  
       --BEGIN          
       -- SET @c_colContent12 = @c_Colcontent          
       --END   
          
       ----ELSE IF @n_intFlag = 13 OR @n_intFlag = 28 OR @n_intFlag = 43 OR @n_intFlag = 58         
       --ELSE IF (@n_ID%@n_MaxLine) = 13  
       --BEGIN          
       -- SET @c_colContent13 = @c_Colcontent          
       --END   
  
       ----ELSE IF @n_intFlag = 14 OR @n_intFlag = 29 OR @n_intFlag = 44  OR @n_intFlag = 59       
       --ELSE IF (@n_ID%@n_MaxLine) = 14  
       --BEGIN          
       -- SET @c_colContent14 = @c_Colcontent          
       --END   

       --ELSE IF (@n_ID%@n_MaxLine) = 15 
       --BEGIN          
       -- SET @c_colContent15 = @c_Colcontent          
       --END 
  
       --ELSE IF @n_intFlag = 15 OR @n_intFlag = 30 OR @n_intFlag = 45  OR @n_intFlag = 60        
      ELSE IF (@n_ID%@n_MaxLine) = 0  
       BEGIN          
        SET @c_colContent08 = @c_Colcontent          
       END   
       
       IF @b_debug='1'
       BEGIN
       	SELECT * FROM #CartonContent WHERE pagenum = @n_Page
       END

      SELECT @n_TTLSKUCNT = SUM(SKUCNT),
             @n_TTLSKUQTY =SUM(SKUQTY)
            -- @n_CNTTTLUCC  = count(UCCID)        --(CS03)
      FROM  #CartonContent c WITH (NOLOCK)                      
      WHERE c.pagenum = @n_Page 
             
      UPDATE #CartonContent
      SET Retrieve = 'Y'
      FROM  #CartonContent c                       
      WHERE c.ID = @n_ID
      AND c.pagenum = @n_Page

       /*CS03 start*/
       SELECT @n_CNTTTLUCC = COUNT(DISTINCT UCCNO)
       FROM UCC WITH (NOLOCK)
       --WHERE ucc.userdefined01=@C_UCCUserdefined01 --(CS05)
       WHERE ucc.id=@c_Uccid 
       
       /*CS03 End*/
                  
       IF @b_debug = '1'              
       BEGIN              
         PRINT ' update for column content1 : ' + @c_ColContent01          
         PRINT ' update for column content2 : ' + @c_ColContent02          
         PRINT ' update for column content3 : ' + @c_ColContent03          
         PRINT ' update for column content4: ' + @c_ColContent04          
         PRINT ' update for column content5 : ' + @c_ColContent05   
         PRINT ' update for column content6 : ' + @c_ColContent06          
         PRINT ' update for column content8: ' + @c_ColContent07          
         PRINT ' update for column content8 : ' + @c_ColContent08       
       END             
                
      UPDATE #Result                    
       SET Col05 = @c_ColContent01,          
           Col06 = @c_ColContent02,                  
           Col07 = @c_ColContent03,           
           Col08 = @c_ColContent04,           
           Col09 = @c_ColContent05,          
           Col10 = @c_ColContent06,          
           Col11 = @c_ColContent07,          
           Col12 = @c_ColContent08,          
           --Col13 = @c_ColContent09,  
           --Col14 = @c_ColContent10,           
           --Col15 = @c_ColContent11,          
           --Col16 = @c_ColContent12,                  
           --Col17 = @c_ColContent13,           
           --Col18 = @c_ColContent14,  
           --Col19 = @c_ColContent15,
           --Col20 = @c_ColContent16,
           Col21 = CONVERT(NVARCHAR(5),@n_TTLSKUCNT),--CONVERT(NVARCHAR(5),@n_CNTTTLUCC), --CONVERT(NVARCHAR(5),@n_TTLSKUCNT),  --(CS03)
           Col22 = CONVERT(NVARCHAR(5),@n_TTLSKUQTY)
       WHERE ID = @n_page           
       
          
     IF @b_debug = '1'          
     BEGIN          
      SELECT convert(nvarchar(3),@n_intFlag),* FROM #Result          
     END          
           
   --SET @n_intFlag = @n_intFlag + 1      

 -- END 
  --ELSE
  

     FETCH NEXT FROM CUR_RowPage INTO @n_ID,@n_Page  
     END -- While                     
      CLOSE CUR_RowPage                    
      DEALLOCATE CUR_RowPage    
               
  -- END      
  FETCH NEXT FROM CUR_RowNoLoop INTO @n_RID,@C_RECEIPTKEY--,@C_UCCUserdefined01               --(CS05)         
            
      END -- While                     
      CLOSE CUR_RowNoLoop                    
      DEALLOCATE CUR_RowNoLoop                
             
          
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_Receiptdate,@C_RUserDefine05,@C_RECEIPTKEY,@C_UCCUserdefined01,@c_Uccid                    
          
   END -- While                     
   CLOSE CUR_StartRecLoop                    
   DEALLOCATE CUR_StartRecLoop            
       
   SELECT * from #result WITH (NOLOCK)  
--   WHERE LEN(ISNULL(Col21,'') +  ISNULL(Col22,'') + ISNULL(Col23,'') +                    
--         ISNULL(Col24,'') +  ISNULL(Col25,'') + ISNULL(Col26,'') +            
--         ISNULL(Col27,'') +  ISNULL(Col28,'') +  ISNULL(Col29,'') +            
--         ISNULL(Col30,'')) > 0            
          
   EXIT_SP:            
          
   SET @d_Trace_EndTime = GETDATE()          
   SET @c_UserName = SUSER_SNAME()          
             
   EXEC isp_InsertTraceInfo           
      @c_TraceCode = 'BARTENDER',          
      @c_TraceName = 'isp_BT_Bartender_TW_Pallet_Label_NIKE',          
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
           
                                    
END -- procedure   

GO