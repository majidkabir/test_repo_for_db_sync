SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

   
/******************************************************************************/         
/* Copyright: IDS                                                             */         
/* Purpose: BarTender Filter by Palletkey,Sku                                 */         
/*                                                                            */         
/* Modifications log:                                                         */         
/*                                                                            */         
/* Date       Rev  Author     Purposes                                        */
/*10/01/2019  1.0  CSCHONG   WMS-7545                                         */            
/******************************************************************************/        
          
CREATE PROC [dbo].[isp_BT_Bartender_PLTSRLABEL_LOGI]               
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
      @c_PalletKey         NVARCHAR(50),            
      @c_SKU               NVARCHAR(20),           
      @c_serialno          NVARCHAR(4000),      
      @c_SQL               NVARCHAR(4000),
      @c_SQLSORT           NVARCHAR(4000),
      @c_SQLJOIN           NVARCHAR(4000),
      @n_TTLCopy           INT,
      @c_ChkStatus         NVARCHAR(2),
      @c_Uccno             NVARCHAR(80),
      @c_storerkey         NVARCHAR(80),
      @n_continue          INT,
      @c_ExecStatements    NVARCHAR(4000),   
      @c_ExecArguments     NVARCHAR(4000),
      @n_MaxLine           INT,   
      @n_pageno            INT   
     

    -- SET RowNo = 0     
    SET @c_SQL = ''  
    SET @n_TTLCopy = 1
    SET @n_MaxLine = 100
      
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


    CREATE TABLE [#TEMPSERIALNo] (                   
      [ID]          [INT] IDENTITY(1,1) NOT NULL,                                      
      [Palletkey]   [NVARCHAR] (50)     NULL,        
      [SKU]         [NVARCHAR] (20)     NULL,  
      [SerialNo]    [NVARCHAR] (50)     NULL,        
      [Pageno]         INT )  

   IF @b_debug='1'
   BEGIN
     PRINT 'Start'
   END  
   
   
       INSERT INTO #TEMPSERIALNo (Palletkey,SKU,SerialNo,Pageno)
       SELECT PLTDET.PalletKey ,
       PD.SKU ,
       sn.SerialNo,
       ROW_NUMBER() OVER (PARTITION BY PLTDET.PalletKey, PD.SKU
                          ORDER BY sn.SerialNo) / @n_MaxLine AS Pageno
       FROM   PALLETDETAIL PLTDET (NOLOCK)
       INNER JOIN PackDetail PD (NOLOCK) ON PD.StorerKey = PLTDET.StorerKey
                                                      AND PLTDET.CaseId = PD.LabelNo
       INNER JOIN SerialNo sn (NOLOCK) ON sn.StorerKey = PD.StorerKey
                                                 AND sn.PickSlipNo = PD.PickSlipNo
                                                 AND sn.CartonNo = PD.CartonNo
      WHERE  PLTDET.PalletKey = @c_Sparm01
      and PD.sku = @c_Sparm02
      AND SN.ExternStatus <> 'CANC' 

   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                           
   SELECT DISTINCT Palletkey,sku,STUFF((SELECT ',' + t1.SerialNo 
   FROM     #TEMPSERIALNo t1 (NOLOCK)
   where t1.palletkey = t2.palletkey and t1.sku=t2.sku and t1.Pageno=t2.Pageno
   ORDER BY t1.SerialNo
   FOR XML PATH('') ),1,1,'')AS serial,pageno 
   from #TEMPSERIALNo t2         
       
   OPEN CUR_RowNoLoop            
       
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_palletKey,@c_sku,@c_serialno,@n_pageno         
         
   WHILE @@FETCH_STATUS <> -1            
   BEGIN         
       
     INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09  
             ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22  
             ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34  
             ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44 
             ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
             ,Col55,Col56,Col57,Col58,Col59,Col60)
      VALUES(@c_palletKey,@c_sku,SUBSTRING(@c_serialno, 1, 80),SUBSTRING(@c_serialno, 81, 80),
          SUBSTRING(@c_serialno, 161, 80),SUBSTRING(@c_serialno, 241, 80),SUBSTRING(@c_serialno, 321, 80),
          SUBSTRING(@c_serialno, 401, 80) ,SUBSTRING(@c_serialno, 481, 80),SUBSTRING(@c_serialno, 561, 80),   --10
          SUBSTRING(@c_serialno, 641, 80),SUBSTRING(@c_serialno, 721, 80),SUBSTRING(@c_serialno, 801, 80),
          SUBSTRING(@c_serialno, 881, 80),SUBSTRING(@c_serialno, 961, 80),SUBSTRING(@c_serialno, 1041, 80),
          SUBSTRING(@c_serialno, 1121, 80),SUBSTRING(@c_serialno, 1201, 80),SUBSTRING(@c_serialno, 1281, 80),
          SUBSTRING(@c_serialno, 1361, 80),SUBSTRING(@c_serialno, 1441, 80),SUBSTRING(@c_serialno, 1521, 80),   --22
          SUBSTRING(@c_serialno, 1601, 80),SUBSTRING(@c_serialno, 1681, 80),SUBSTRING(@c_serialno, 1761, 80),   --25
          SUBSTRING(@c_serialno, 1841, 80),SUBSTRING(@c_serialno, 1921, 80),SUBSTRING(@c_serialno, 2001, 80),
          SUBSTRING(@c_serialno, 2081, 80),SUBSTRING(@c_serialno, 2161, 80),
          '','','','','','','','','','',
          '','','','','','','','','','',
          '','','','','','','','','',''
          )
       

   FETCH NEXT FROM CUR_RowNoLoop INTO @c_palletKey,@c_sku,@c_serialno,@n_pageno  
   END   
   
   CLOSE CUR_RowNoLoop                  
    DEALLOCATE CUR_RowNoLoop
    
   SELECT * FROM #Result WITH (NOLOCK)

   DROP TABLE #TEMPSERIALNo 

   EXIT_SP:       
                               
   END -- procedure     


GO