SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: BarTender sku label                                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2023-05-05 1.0  CSCHONG    Created (WMS-22412)                             */
/* 2023-05-08 1.0  CSCHONG    DevOps Combine Script                           */
/******************************************************************************/

CREATE   PROC [dbo].[isp_Bartender_SG_UCCLBLSG03_01]
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
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @n_copy            INT,
      @c_ExternOrderKey  NVARCHAR(10),
      @c_Deliverydate    DATETIME,
      @n_intFlag         INT,
      @n_CntRec          INT,
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000)

  DECLARE  @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime     DATETIME,
           @c_Trace_ModuleName  NVARCHAR(20),
           @d_Trace_Step1       DATETIME,
           @c_Trace_Step1       NVARCHAR(20),
           @c_UserName          NVARCHAR(20),
           @c_ExecArguments     NVARCHAR(4000),
           @c_Orderkey          NVARCHAR(80) = '',
           @n_ctnctn            INT = '0',
           @c_Col01             NVARCHAR(80) = '',
           @c_Col02             NVARCHAR(80) = '',
           @c_Col03             NVARCHAR(80) = '',
           @c_Col04             NVARCHAR(80) = '',
           @c_Col05             NVARCHAR(80) = '',
           @c_Col06             NVARCHAR(80) = '',
           @c_Col07             NVARCHAR(80) = '',
           @c_Col08             NVARCHAR(80) = '',
           @c_Col09             NVARCHAR(80) = '',
           @c_Col11             NVARCHAR(80) = '',
           @c_Col15             NVARCHAR(80) = '',
           @c_NOTPPA            NVARCHAR(1) = 'N',
           @c_Storerkey         NVARCHAR(15),  
           @c_pickslipno        NVARCHAR(20),
           @c_chkNOTPPA1        NVARCHAR(1) ='N',  
           @c_chkNOTPPA2        NVARCHAR(1) = 'N',
           @c_PHStatus          NVARCHAR(10),  
           @c_Col17             NVARCHAR(80) = ''    
 

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

     IF ISNULL(@c_Sparm01,'') = ''
     BEGIN
            GOTO EXIT_SP
     END

   SELECT @c_pickslipno = PH.PickSlipNo    
         ,@c_Storerkey = PH.StorerKey
         ,@c_PHStatus   = PH.Status   
   FROM PACKHEADER PH WITH (NOLOCK)                                           
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)    
   WHERE PD.dropid = @c_Sparm01 AND PD.Storerkey = 'AESOP' 


     SELECT @c_Orderkey = MAX(PH.OrderKey)
         --  ,@n_ctnctn = COUNT(PD.CartonNo)
     From PackHeader PH WITH (NOLOCK)
     JOIN PackDetail PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
     WHERE PD.DropID = @c_Sparm01 AND PH.storerkey='AESOP'

     SELECT @n_ctnctn = COUNT(DISTINCT PD.CartonNo)  
     From PackHeader PH WITH (NOLOCK)    
     JOIN PackDetail PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno    
     WHERE PH.OrderKey = @c_Orderkey AND PH.storerkey='AESOP' 

     IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)  
                         JOIN PackHeader PH WITH (NOLOCK) ON PH.OrderKey=OH.OrderKey  
                WHERE PH.PickSlipNo =@c_pickslipno AND PH.StorerKey = @c_Storerkey  
                AND ISNULL(OH.M_vat,'') = 'PPA')  
      BEGIN     
  
             IF EXISTS   
            ( SELECT 1 FROM PackDetail PAD  
                LEFT JOIN rdt.RdtPPA PPA ON PPA.Storerkey = @c_Storerkey And PPA.DropID = @c_Sparm01 And PPA.Sku = PAD.SKU  
                Where PAD.Storerkey = @c_Storerkey  
               AND PAD.DropID = @c_Sparm01                              
                HAVING sum(PAD.Qty) <> sum(IsNull(PPA.CQty,0))  
            )  
            BEGIN  
               SET @c_chkNOTPPA1 = 'Y'  
            END  
  
            IF EXISTS  
            ( SELECT 1 FROM rdt.RDTPPA PPA  
                Where PPA.Storerkey = @c_Storerkey   
               And PPA.DropID = @c_Sparm01  
                And PPA.CQty > 0   
                And NOT EXISTS (SELECT 1   
                           FROM PackDetail PAD WHERE PAD.Storerkey = @c_Storerkey  
                           AND PAD.DropID = @c_Sparm01                    
                           And PAD.Sku = PPA.SKU)  
            )  
            BEGIN  
               SET @c_chkNOTPPA2 = 'Y'  
            END  
        END   

            IF @c_chkNOTPPA1 = 'Y' OR @c_chkNOTPPA2 = 'Y'  
            BEGIN  
              SET @c_NOTPPA = 'Y'   
            END  

   
     SELECT @c_Col01 = OH.ExternOrderKey
           ,@c_Col02 = OH.C_Company
           ,@c_Col03 = ISNULL(OH.C_Address1,'')
           ,@c_Col04 = ISNULL(OH.C_Address2,'')
           ,@c_Col05 = ISNULL(OH.C_Address3,'') 
           ,@c_Col06 = ISNULL(OH.C_Address4,'')
           ,@c_Col07 = ISNULL(OH.C_Country,'')
           ,@c_Col08 = ISNULL(OH.C_Zip,'')
           ,@c_Col09 = ISNULL(OH.C_contact1,'')
           ,@c_Col11 = CASE WHEN @c_PHStatus <> '9' THEN 'NOTPACK' ELSE CASE WHEN @c_NOTPPA = 'Y' THEN  'NOTPPA' ELSE OH.[Route] END END --ISNULL(OH.Route,'')
           ,@c_Col15 = ISNULL(CONVERT(NVARCHAR(10),OH.DeliveryDate,103),'')
           ,@c_Col17 = ISNULL(OH.Consigneekey,'')  
     FROM ORDERS  OH (NOLOCK)
     WHERE OH.OrderKey = @c_Orderkey

    INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09
                        ,Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22
                        ,Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34
                        ,Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44
                        ,Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54
                        ,Col55,Col56,Col57,Col58,Col59,Col60)
    SELECT  TOP 1 @c_Col01,@c_Col02,@c_col03,@c_col04,@c_Col05, @c_Col06,@c_Col07,@c_Col08,@c_Col09,PH.EditWho,
              @c_Col11,PD.CartonNo,PD.DropID,@n_ctnctn,@c_Col15,IsNull(PD.RefNo2,''),@c_Col17,'','','',  --20
              '','','','','','','','','','',  --30
              '','','','','','','','','','',   --40
              '','','','','','','','','','',   --50
              '','','','','','','','','',''    --60
     From PackHeader PH WITH (NOLOCK)
     JOIN PackDetail PD WITH (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
     WHERE PD.DropID = @c_Sparm01

      IF @b_debug='1'
      BEGIN
        PRINT @c_SQL
      END
      IF @b_debug='1'
      BEGIN
        SELECT * FROM #Result (nolock)
      END

      SELECT * FROM #Result (nolock)

EXIT_SP:

   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()

END -- procedure



GO