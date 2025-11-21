SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_BT_Bartender_CN_NKESHIPLBL_01                                 */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2022-06-29 1.0  CSCHONG    DevOps Scripts Combine & Created(WMS-20089)     */
/* 2022-08-04 1.1  CSCHONG    WMS-20089 revised field logic (CS01)            */
/* 2022-08-25 1.2  CSCHONG    WMS-20089 Fix col16 retrive error (CS01a)       */
/******************************************************************************/

CREATE PROC [dbo].[isp_BT_Bartender_CN_NKESHIPLBL_01]
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
      @c_ReceiptKey      NVARCHAR(10),
      @c_sku             NVARCHAR(20),
      @n_intFlag         INT,
      @n_CntRec          INT,
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000)

  DECLARE   @d_Trace_StartTime   DATETIME,
    @d_Trace_EndTime    DATETIME,
    @c_Trace_ModuleName NVARCHAR(20),
    @d_Trace_Step1      DATETIME,
    @c_Trace_Step1      NVARCHAR(20),
    @c_UserName         NVARCHAR(20),
    @c_col01            NVARCHAR(80),
    @c_col02            NVARCHAR(80),
    @c_col03            NVARCHAR(80),
    @c_col04            NVARCHAR(80),
    @c_col05            NVARCHAR(80),
    @c_col06            NVARCHAR(80),
    @c_col07            NVARCHAR(80),
    @c_col08            NVARCHAR(80),
    @c_col09            NVARCHAR(80),
    @c_col10            NVARCHAR(80),
    @c_col11            NVARCHAR(80),
    @c_col12            NVARCHAR(80),
    @c_col13            NVARCHAR(80),
    @c_col14            NVARCHAR(80),
    @c_Col15            NVARCHAR(80), 
    @c_col16            NVARCHAR(80),
    @n_cartonno         INT, 
    @c_labelno          NVARCHAR(20), 
    @n_TTLpage          INT,
    @n_CurrentPage      INT,
    @n_MaxLine          INT  ,
    @c_storerkey        NVARCHAR(20) ,
    @c_ExecStatements   NVARCHAR(4000),
    @c_ExecArguments    NVARCHAR(4000)

DECLARE @c_printdata            NVARCHAR(MAX),
        @c_DelimiterSign1       NVARCHAR(5),
        @c_DelimiterSign2       NVARCHAR(5),
        @n_SeqNo1               INT,
        @c_ColValue1            NVARCHAR(150),   
        @n_SeqNo2               INT,
        @c_ColValue2            NVARCHAR(150), 
        @c_cartoninfo           NVARCHAR(100),
        @c_cartonId             NVARCHAR(50),
        @c_pcs                  NVARCHAR(10),
        @c_getctnno             NVARCHAR(2)                --CS01a 

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

    -- SET RowNo = 0
    SET @c_SQL = ''
    SET @n_CurrentPage = 1
    SET @n_TTLpage =1
    SET @n_MaxLine = 5
    SET @n_CntRec = 1
    SET @n_intFlag = 1
    SET @c_DelimiterSign1 = ';'
    SET @c_DelimiterSign2 = ','

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



         SELECT @c_col01 = OH.OrderKey,
                @c_col02 = OH.LoadKey,
                @c_col03 = OH.C_Company,
                @c_col04 = ISNULL(OH.C_Address2,'') + ISNULL(OH.C_Address3,''),    --CS01
                @c_col05 = OH.C_City,
                @c_col06 = OH.C_State,
                @c_col07 = OH.c_zip,
                @c_col08 = OH.BillToKey,
                @c_col09 = OH.B_Company,
                @c_col10 = ISNULL(OH.B_Address2,'') + ISNULL(OH.B_Address3,''),   --CS01
                @c_col11 = OH.B_City,
                @c_col12 = OH.B_State,
                @c_col13 = OH.B_Zip,
                @c_printdata = ISNULL(CT.PrintData,'')
         FROM ORDERS OH WITH (NOLOCK)
         LEFT JOIN CartonTrack CT WITH (NOLOCK) ON CT.LabelNo=OH.OrderKey
         WHERE OH.LoadKey=@c_Sparm01
         AND OH.OrderKey = @c_Sparm02
         ORDER BY OH.LoadKey DESC


     IF ISNULL(@c_printdata,'') = ''
     BEGIN
       GOTO EXIT_SP
     END 

          DECLARE C_DelimSplit1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT SeqNo, ColValue 
          FROM dbo.fnc_DelimSplit(@c_DelimiterSign1,@c_printdata)
     
           OPEN C_DelimSplit1
           FETCH NEXT FROM C_DelimSplit1 INTO @n_SeqNo1, @c_ColValue1

           WHILE (@@FETCH_STATUS=0) 
           BEGIN
           

           SET @c_cartoninfo = @c_ColValue1
    

           SET @c_cartoninfo = REPLACE(@c_cartoninfo,'"','')

           IF @b_debug = '1'
           BEGIN
               SELECT REPLACE(@c_cartoninfo,'"','') '@c_cartoninfo'
           END


                 DECLARE C_DelimSplit2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                 SELECT SeqNo, ColValue 
                 FROM dbo.fnc_DelimSplit(@c_DelimiterSign2,@c_cartoninfo)
     
                 OPEN C_DelimSplit2
                 FETCH NEXT FROM C_DelimSplit2 INTO @n_SeqNo2, @c_ColValue2

                 WHILE (@@FETCH_STATUS=0) 
                 BEGIN

                 IF @b_debug = '1' AND @n_SeqNo2 = 2
                 BEGIN
                    SELECT @n_SeqNo2 'seq2',@c_ColValue2 'col2'
                 END

                 SET @c_col16 = ''
                 SET @n_cartonno = 0 

                 IF @n_SeqNo2= 1
                 BEGIN
                  SET @c_col14 = LTRIM(@c_ColValue2)     --CS01a
                 END
                 ELSE IF @n_SeqNo2 = 2
                 BEGIN
                  SET @c_col15 = @c_ColValue2
                 END
                 IF @b_debug = '1' AND @n_SeqNo2 = 2
                 BEGIN

                 SELECT @c_col14 'Cartonid',@c_col15 'pcs'

                  END

                      --IF LEN(@c_col14) = 19       --CS01a S
                      --BEGIN
                      --     SET @n_cartonno = CAST(RIGHT(@c_col14,1) AS INT)
                      --END 
                      --ELSE IF LEN(@c_col14) = 20
                      --BEGIN
                      --     SET @n_cartonno = CAST(RIGHT(@c_col14,2) AS INT)
                      --END 
                      SET  @c_getctnno = RIGHT(@c_col14,2)
                      
                       IF LEFT(@c_getctnno,1) = '0'
                       BEGIN    
                           SET @n_cartonno = CAST(RIGHT(@c_getctnno,1) AS INT) 
                       END
                       ELSE
                       BEGIN
                           SET @n_cartonno = @c_getctnno
                       END  
                     
                       IF @b_debug = '2' 
                       BEGIN
                             SELECT @n_cartonno '@n_cartonno'
                       END  
                  --CS01 E

                  IF @n_cartonno <> 0
                  BEGIN
           
                     select top 1 @c_col16 = SUBSTRING(od.notes,1,80)
                     from packdetail(nolock) pad 
                     join pickdetail(nolock) pid on pad.labelno=pid.caseid and pad.storerkey=pid.storerkey and pad.sku=pid.sku 
                     join orderdetail(nolock) od on od.orderkey=pid.orderkey and od.storerkey=pid.storerkey and od.orderlineNumber=pid.orderlineNumber
                     where pad.cartonno=@n_cartonno and od.orderkey=@c_Sparm02 --and od.storerkey='nikesdc'

                  END

                  IF @b_debug = '1' AND @n_SeqNo2 = 2
                 BEGIN

                 SELECT @c_col14 'Cartonid',@c_col15 'pcs', @n_cartonno '@n_cartonno', @c_col16 '@c_col16'

                END

                IF @n_SeqNo2 = 2
                BEGIN

                    INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                                 ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                                 ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                                 ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                                 ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                                 ,Col55,Col56,Col57,Col58,Col59,Col60)
                   VALUES(@c_col01,@c_col02,@c_col03,@c_col04,@c_col05,@c_col06,@c_col07,@c_col08,@c_col09,@c_col10,
                          @c_col11,@c_col12,@c_col13,@c_col14,@c_col15,@c_col16,'','','','',
                          '','','','','','','','','','', 
                          '','','','','','','','','','',
                          '','','','','','','','','','',
                          '','','','','','','','','','') 

                END    

                FETCH NEXT FROM C_DelimSplit2 INTO @n_SeqNo2, @c_ColValue2
                 END -- WHILE (@@FETCH_STATUS <> -1) AND @n_Continue <> 3
     
                 CLOSE C_DelimSplit2
                 DEALLOCATE C_DelimSplit2
       

     FETCH NEXT FROM C_DelimSplit1 INTO @n_SeqNo1, @c_ColValue1
     END -- WHILE (@@FETCH_STATUS <> -1) AND @n_Continue <> 3
     
     CLOSE C_DelimSplit1
     DEALLOCATE C_DelimSplit1

   IF @b_debug=1
   BEGIN
      SELECT * FROM #Result (nolock)
   END

SELECT * FROM #Result (nolock)

EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()




END -- procedure


GO