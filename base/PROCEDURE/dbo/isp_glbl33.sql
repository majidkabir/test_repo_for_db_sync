SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_GLBL33                                          */
/* Creation Date: 17-Feb-2022                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-18965 - HK AEO new UCC format requirement               */
/*          Configured by CODELKUP.ListName = LBLNOCFG                  */
/*          RuleExp (Notes) Special Keywords: **GetUCCKey, **CheckDigit */
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 17-Feb-2022  WLChooi 1.0   DevOps Combine Script                     */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL33] (
         @c_PickSlipNo   NVARCHAR(10)
      ,  @n_CartonNo     INT
      ,  @c_LabelNo      NVARCHAR(20) OUTPUT
      ,  @c_DropID       NVARCHAR(20) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt      INT
         , @n_Continue       INT
         , @b_Success        INT
         , @n_Err            INT
         , @c_ErrMsg         NVARCHAR(255)
         , @c_Code2          NVARCHAR(30)  = ''
         , @c_Consol         NVARCHAR(1)   = ''
         , @c_Storerkey      NVARCHAR(15)  = ''
         , @c_Orderkey       NVARCHAR(10)  = ''
         , @c_Loadkey        NVARCHAR(10)  = ''
         , @c_Wavekey        NVARCHAR(10)  = ''
         , @c_SQL            NVARCHAR(MAX)
         , @c_SQLParam       NVARCHAR(MAX)
         , @c_RuleNo         NVARCHAR(10)
         , @c_RuleExp        NVARCHAR(MAX)
         , @c_Action         NVARCHAR(60)
         , @c_LeadingChar    NVARCHAR(60)
         , @n_StartPos       INT
         , @n_Length         INT
         , @c_Temp01         NVARCHAR(MAX) = ''
         , @c_Temp02         NVARCHAR(MAX) = ''
         , @c_Temp03         NVARCHAR(MAX) = ''
         , @c_Temp04         NVARCHAR(MAX) = ''
         , @c_Temp05         NVARCHAR(MAX) = ''
         , @c_Temp06         NVARCHAR(MAX) = ''
         , @c_Temp07         NVARCHAR(MAX) = ''
         , @c_Temp08         NVARCHAR(MAX) = ''
         , @c_Temp09         NVARCHAR(MAX) = ''
         , @c_Temp10         NVARCHAR(MAX) = ''
         , @c_RetVal         NVARCHAR(MAX) = ''

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
   SET @c_LabelNo          = ''

   SELECT @b_success = 1, @c_errmsg='', @n_err=0

   SELECT @c_Storerkey = OH.Storerkey
        , @c_Orderkey  = OH.Orderkey
        , @c_Loadkey   = OH.Loadkey
        , @c_Wavekey   = OH.UserDefine09
        , @c_Consol    = 'N'
   FROM dbo.PACKHEADER PH(NOLOCK)
   JOIN dbo.ORDERS     OH(NOLOCK) ON PH.Orderkey=OH.Orderkey
   WHERE PH.PickslipNo = @c_Pickslipno

   IF ISNULL(@c_Storerkey,'')=''
   BEGIN
      SELECT TOP 1
             @c_Storerkey = OH.Storerkey
           , @c_Orderkey  = OH.Orderkey
           , @c_Loadkey   = OH.Loadkey
           , @c_Wavekey   = OH.UserDefine09
           , @c_Consol    = 'Y'
      FROM dbo.PACKHEADER PH(NOLOCK)
      JOIN dbo.LoadPlanDetail LPD(NOLOCK) ON LPD.LoadKey=PH.LoadKey
      JOIN dbo.ORDERS     OH(NOLOCK) ON OH.OrderKey=LPD.OrderKey
      WHERE PH.PickslipNo = @c_Pickslipno
      AND ISNULL(PH.Orderkey,'') = '' 
      AND ISNULL(PH.Loadkey,'') <> ''
      ORDER BY OH.Orderkey
   END

   IF EXISTS(SELECT TOP 1 1 FROM dbo.CodeLkup WITH (NOLOCK)
             WHERE Listname = 'LBLNOCFG' AND Storerkey = @c_StorerKey)
   BEGIN
      SET @c_SQLParam = '@cPickSlipNo  NVARCHAR(10)'
                      +',@nCartonNo    INT'
                      +',@cDropID      NVARCHAR(20)'
                      +',@cConsol      NVARCHAR(1)'
                      +',@cStorerkey   NVARCHAR(15)'
                      +',@cOrderkey    NVARCHAR(10)'
                      +',@cLoadkey     NVARCHAR(10)'
                      +',@cWavekey     NVARCHAR(10)'
                      +',@cLabelNo     NVARCHAR(20)  OUTPUT'
                      +',@cTemp01      NVARCHAR(MAX) OUTPUT'
                      +',@cTemp02      NVARCHAR(MAX) OUTPUT'
                      +',@cTemp03      NVARCHAR(MAX) OUTPUT'
                      +',@cTemp04      NVARCHAR(MAX) OUTPUT'
                      +',@cTemp05      NVARCHAR(MAX) OUTPUT'
                      +',@cTemp06      NVARCHAR(MAX) OUTPUT'
                      +',@cTemp07      NVARCHAR(MAX) OUTPUT'
                      +',@cTemp08      NVARCHAR(MAX) OUTPUT'
                      +',@cTemp09      NVARCHAR(MAX) OUTPUT'
                      +',@cTemp10      NVARCHAR(MAX) OUTPUT'
                      +',@bSuccess     INT           OUTPUT'
                      +',@nErr         INT           OUTPUT'
                      +',@cErrMsg      NVARCHAR(255) OUTPUT'
                      +',@cRetVal      NVARCHAR(MAX) OUTPUT'

      DECLARE CUR_LBLNOCFG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT RuleNo = RTRIM(Code)
      FROM dbo.CodeLkup WITH (NOLOCK)
      WHERE Listname = 'LBLNOCFG' AND Storerkey = @c_StorerKey
      ORDER BY 1

      OPEN CUR_LBLNOCFG

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM CUR_LBLNOCFG
         INTO @c_RuleNo

         IF @@FETCH_STATUS<>0
            BREAK

         SELECT @c_RuleExp = ''
              , @c_Action  = ''
              , @b_Success = 1

         SELECT TOP 1
                @c_RuleExp = RTRIM(Notes2)
              , @c_Action  = RTRIM(UDF02)
         FROM dbo.CodeLkup WITH (NOLOCK)
         WHERE Listname = 'LBLNOCFG' AND Storerkey = @c_StorerKey AND Code=@c_RuleNo
         ORDER BY CASE WHEN ISNULL(Notes2,'')<>'' THEN 1 ELSE 2 END, Code2

         IF ISNULL(@c_RuleExp,'')<>''
         BEGIN
            SELECT @b_Success = 0
                 , @n_Err    = 0
                 , @c_ErrMsg = ''

            IF @c_Action = 'DECODE'
               SET @c_SQL = @c_RuleExp
            ELSE
               SET @c_SQL = 'IF (' + @c_RuleExp + ') SET @bSuccess=1'

            BEGIN TRY
               EXEC sp_ExecuteSQL @c_SQL, @c_SQLParam
                  , @c_PickSlipNo
                  , @n_CartonNo
                  , @c_DropID
                  , @c_Consol
                  , @c_Storerkey
                  , @c_Orderkey
                  , @c_Loadkey
                  , @c_Wavekey
                  , @c_LabelNo    OUTPUT
                  , @c_Temp01     OUTPUT
                  , @c_Temp02     OUTPUT
                  , @c_Temp03     OUTPUT
                  , @c_Temp04     OUTPUT
                  , @c_Temp05     OUTPUT
                  , @c_Temp06     OUTPUT
                  , @c_Temp07     OUTPUT
                  , @c_Temp08     OUTPUT
                  , @c_Temp09     OUTPUT
                  , @c_Temp10     OUTPUT
                  , @b_Success    OUTPUT
                  , @n_Err        OUTPUT
                  , @c_ErrMsg     OUTPUT
                  , @c_RetVal     OUTPUT
            END TRY
            BEGIN CATCH
               SET @n_Continue = 3
               SET @n_Err = 65020
               SET @c_ErrMsg= 'NSQL' + CONVERT(CHAR(5),@n_Err)+': Rule Condition ERR ' + ISNULL(@c_RuleNo,'') + '. (isp_GLBL33)' 
                            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) ' 
               BREAK
            END CATCH
         END

         IF @b_Success = 1
         BEGIN
            SELECT @c_LabelNo = ''
                 , @c_Temp01  = ''
                 , @c_Temp02  = ''
                 , @c_Temp03  = ''
                 , @c_Temp04  = ''
                 , @c_Temp05  = ''
                 , @c_Temp06  = ''
                 , @c_Temp07  = ''
                 , @c_Temp08  = ''
                 , @c_Temp09  = ''
                 , @c_Temp10  = ''

            DECLARE CUR_LABELNOCONFIG_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Code2       = RTRIM(Code2)
                 , StartPos    = TRY_PARSE(ISNULL(Short,'') AS INT)
                 , Length      = TRY_PARSE(ISNULL(Long,'') AS INT)
                 , RuleExp     = RTRIM(ISNULL(Notes,''))
                 , Action      = RTRIM(ISNULL(UDF01,''))
                 , LeadingChar = RTRIM(ISNULL(UDF03,''))   -- e.g. Leading Zero=0*, Padding Zero=*0
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE Listname = 'LBLNOCFG' AND Storerkey = @c_StorerKey AND Code=@c_RuleNo
            ORDER BY Code2

            OPEN CUR_LABELNOCONFIG_DET

            WHILE 1=1
            BEGIN
               FETCH NEXT FROM CUR_LABELNOCONFIG_DET
               INTO @c_Code2, @n_StartPos, @n_Length, @c_RuleExp, @c_Action, @c_LeadingChar

               IF @@FETCH_STATUS<>0
                  BREAK

               SELECT @b_Success = 1
                    , @n_Err     = 0
                    , @c_ErrMsg  = ''
                    , @c_RetVal  = ''

               IF ISNULL(@c_RuleExp,'')<>''
               BEGIN
                  IF @c_RuleExp = '**GetUCCKey'
                  BEGIN
                     IF ISNULL(@n_StartPos,0)>0 AND ISNULL(@n_Length,0)>0
                        EXEC isp_getucckey @c_Storerkey, @n_Length, @c_RetVal OUTPUT, 0, 0, '', 0, 1
                  END
                  ELSE IF @c_RuleExp = '**CheckDigit'
                  BEGIN
                     SET @c_RetVal = dbo.fnc_CalcCheckDigit_M10(@c_LabelNo,0)
                  END
                  ELSE
                  BEGIN
                     IF @c_Action = 'DECODE'
                        SET @c_SQL = @c_RuleExp
                     ELSE
                        SET @c_SQL = 'SET @cRetVal = (' + @c_RuleExp + ')'

                     BEGIN TRY
                        EXEC sp_ExecuteSQL @c_SQL, @c_SQLParam
                           , @c_PickSlipNo
                           , @n_CartonNo
                           , @c_DropID
                           , @c_Consol
                           , @c_Storerkey
                           , @c_Orderkey
                           , @c_Loadkey
                           , @c_Wavekey
                           , @c_LabelNo    OUTPUT
                           , @c_Temp01     OUTPUT
                           , @c_Temp02     OUTPUT
                           , @c_Temp03     OUTPUT
                           , @c_Temp04     OUTPUT
                           , @c_Temp05     OUTPUT
                           , @c_Temp06     OUTPUT
                           , @c_Temp07     OUTPUT
                           , @c_Temp08     OUTPUT
                           , @c_Temp09     OUTPUT
                           , @c_Temp10     OUTPUT
                           , @b_Success    OUTPUT
                           , @n_Err        OUTPUT
                           , @c_ErrMsg     OUTPUT
                           , @c_RetVal     OUTPUT
                     END TRY
                     BEGIN CATCH
                        SET @n_Continue = 3
                        SET @n_Err = 65025
                        SET @c_ErrMsg= 'NSQL' + CONVERT(CHAR(5),@n_Err)+': Rule Expression ERR ' + ISNULL(@c_RuleNo,'') +'-'+ ISNULL(@c_Code2,'') + '. (isp_GLBL33)' 
                                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) ' 
                        BREAK
                     END CATCH
                  END

                  IF @n_Err <> 0
                  BEGIN
                     SET @n_Continue = 3
                     BREAK
                  END
                  ELSE IF @b_Success = 0   -- Stop Detail Rules loop
                     BREAK
               END

               IF ISNULL(@n_StartPos,0)>0 AND ISNULL(@n_Length,0)>0 AND @c_RetVal IS NOT NULL
               BEGIN
                  IF @c_LeadingChar LIKE '_*'        -- Pad prefix char
                     SET @c_RetVal = RIGHT( REPLICATE( LEFT(@c_LeadingChar+' ',1), @n_Length) + @c_RetVal, @n_Length)
                  ELSE IF @c_LeadingChar LIKE '*_'   -- Pad suffix char
                     SET @c_RetVal = LEFT( @c_RetVal + REPLICATE( SUBSTRING(@c_LeadingChar+'  ',2,1), @n_Length), @n_Length)
                  ELSE
                     SET @c_RetVal = LEFT( @c_RetVal + SPACE(@n_Length), @n_Length)

                  SET @c_LabelNo = RTRIM(STUFF(@c_LabelNo + SPACE(@n_StartPos), @n_StartPos, @n_Length, @c_RetVal))
               END
            END

            CLOSE CUR_LABELNOCONFIG_DET
            DEALLOCATE CUR_LABELNOCONFIG_DET

            BREAK
         END
      END

      CLOSE CUR_LBLNOCFG
      DEALLOCATE CUR_LBLNOCFG
   END

   IF ISNULL(@c_LabelNo,'') = ''
   BEGIN
      EXEC isp_GenUCCLabelNo
          @c_Storerkey,
          @c_LabelNo OUTPUT,
          @b_success OUTPUT,
          @n_err     OUTPUT,
          @c_errmsg  OUTPUT

      IF @b_Success <> 1
         SELECT @n_Continue = 3
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_LABELNOCONFIG_DET') IN (0 , 1)
   BEGIN
      CLOSE CUR_LABELNOCONFIG_DET
      DEALLOCATE CUR_LABELNOCONFIG_DET   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_LBLNOCFG') IN (0 , 1)
   BEGIN
      CLOSE CUR_LBLNOCFG
      DEALLOCATE CUR_LBLNOCFG   
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GLBL33'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO