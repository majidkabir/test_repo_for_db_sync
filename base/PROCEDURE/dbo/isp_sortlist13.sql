SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_SortList13                                         */
/* Creation Date: 14-FEB-2014                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Generate Adidas PickSlip                                      */
/*           SOS#301740 - [Adidas] Modify Wave Pick Slip to Auto Gen       */
/*           PickHeader Records                                            */
/* Called By: PB: r_dw_sortlist13                                          */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 31-MAR-2014  YTWan     1.1   To Insert Loadkey to Pickheader            */
/*                              ExternOrkderkey (Wan01)                    */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/***************************************************************************/
CREATE PROC [dbo].[isp_SortList13]
           @c_Wavekey NVARCHAR(10) 
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_StartTCnt       INT            -- Holds the current transaction count    
         , @n_Err             INT
         , @b_Success         INT
         , @c_errmsg          INT

   DECLARE @n_NoOfPickSlip    INT
         , @c_PickHeaderKey   NVARCHAR(10)
         , @c_PrintedFlag     NVARCHAR(1)
         , @c_Orderkey        NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @n_GenPickSlip     INT


   SET @n_StartTCnt     = @@TRANCOUNT
   SET @n_Err           = 0
   SET @b_Success       = 1
   SET @c_errmsg        = ''

   SET @n_NoOfPickSlip  = ''
   SET @c_PickHeaderKey = ''
   SEt @c_PrintedFlag   = 'N'

   SET @c_Orderkey      = ''

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   SELECT TOP 1 @c_Storerkey = Storerkey
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (WD.ORderkey = OH.ORderkey)
   WHERE WD.Wavekey = @c_Wavekey

   SET @n_GenPickSlip = 0
   SELECT @n_GenPickSlip = ISNULL(MAX(CASE WHEN Code = 'GenPickSlip' THEN 1 ELSE 0 END),0)
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND   Storerkey= @c_Storerkey
   AND   Long     = 'r_dw_sortlist13'
   AND   (Short    IS NULL OR Short = 'N')


   IF @n_GenPickSlip = 0 
   BEGIN
      GOTO QUIT
   END

  CREATE TABLE #TMP_PICK
      (  SeqNo             INT      IDENTITY(1,1)  NOT NULL
      ,  PickSlipNo        NVARCHAR(10)
      ,  Wavekey           NVARCHAR(10)   NULL
      ,  Orderkey          NVARCHAR(10)   NULL
      ,  ExternORderkey    NVARCHAR(50)   NULL              --tlting_ext  --(Wan01)
      )
       
   BEGIN TRAN

   INSERT INTO #TMP_PICK
         (  PickSlipNo
         ,  WaveKey        
         ,  Orderkey 
         ,  ExternORderkey                                  --(Wan01)      
         )
   SELECT   PickSlipNo     = ISNULL(RTRIM(PH.PickHeaderKey),'')     
         ,  Wavekey        = @c_Wavekey
         ,  Orderkey       = PD.OrderKey 
         ,  ExternORderkey = OH.Loadkey                     --(Wan01)
   FROM WAVEDETAIL      WD   WITH (NOLOCK)
   JOIN ORDERS          OH   WITH (NOLOCK) ON (WD.OrderKey = OH.Orderkey) 
   JOIN PICKDETAIL      PD   WITH (NOLOCK) ON (WD.OrderKey = PD.Orderkey)
   LEFT JOIN PICKHEADER PH   WITH (NOLOCK) ON (WD.Wavekey = PH.Wavekey)
                                           AND(WD.Orderkey= PH.Orderkey)
  WHERE PD.Status  >= '0'  
    AND WD.WaveKey = @c_Wavekey
  GROUP BY  ISNULL(RTRIM(PH.PickHeaderKey),'')                                  
         ,  PD.OrderKey 
         ,  OH.Loadkey                                                         

   UPDATE PICKHEADER WITH (ROWLOCK)
   SET PickType = '1' 
      ,TrafficCop = NULL
   WHERE Wavekey = @c_Wavekey
   AND Zone = '8'
   AND PickType = '0'
   
   SET @n_err = @@ERROR

   IF @n_err <> 0 
   BEGIN
      IF @@TRANCOUNT >= 1
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      IF @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
      ELSE
      BEGIN
         ROLLBACK TRAN
      END
   END

   SELECT @n_NoOfPickSlip = COUNT(DISTINCT Orderkey)
   FROM #TMP_PICK 
   WHERE PickSlipNo = ''

   IF @n_NoOfPickSlip = 0
   BEGIN
      GOTO QUIT
   END

   EXECUTE nspg_GetKey 'PICKSLIP'
                     , 9
                     , @c_PickHeaderKey   OUTPUT
                     , @b_success         OUTPUT
                     , @n_err             OUTPUT
                     , @c_errmsg          OUTPUT
                     , 0
                     , @n_NoOfPickSlip


   BEGIN TRAN
   INSERT INTO PICKHEADER 
         (  PickHeaderKey
         ,  OrderKey
         ,  Wavekey
         ,  ExternOrderkey                               --(Wan01)
         ,  PickType
         ,  Zone
         ,  TrafficCop
         )
   SELECT  'P' + RIGHT ( '000000000' + 
         LTRIM(RTRIM(STR( CAST(@c_PickHeaderKey AS INT) + 
                          (SELECT COUNT(DISTINCT Orderkey) 
                           FROM #TMP_PICK AS RANK 
                           WHERE RANK.OrderKey < #TMP_PICK.OrderKey 
                           AND Rank.PickSlipNo = '')
                         ))),9) 
      , OrderKey
      , Wavekey
      , ExternORderkey                                   --(Wan01)
      , '0'
      , '8'-- '3'
      , ''
   FROM #TMP_PICK 
   WHERE PickSlipNo = ''
   GROUP BY WaveKey
         ,  OrderKey
         ,  ExternOrderkey
   ORDER BY OrderKey

   UPDATE #TMP_PICK 
   SET   PickSlipNo = PICKHEADER.PickHeaderKey
   FROM  PICKHEADER WITH (NOLOCK)
   WHERE PICKHEADER.WaveKey = #TMP_PICK.Wavekey
   AND   PICKHEADER.OrderKey = #TMP_PICK.OrderKey
   AND   PICKHEADER.Zone = '8'
   AND   #TMP_PICK.PickSlipNo = ''

   COMMIT TRAN

   DROP Table #TMP_PICK


   QUIT:

	SELECT DISTINCT Wavekey = ISNULL(RTRIM(WD.Wavekey),'')
			,Loc              = ISNULL(RTRIM(PD.Loc),'')
			,LocationType     = ISNULL(RTRIM(LOC.LocationType),'')
	FROM WAVEDETAIL      WD  WITH (NOLOCK)
	JOIN PICKDETAIL      PD  WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)
	JOIN LOC             LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
	WHERE WD.Wavekey = @c_Wavekey
	ORDER BY ISNULL(RTRIM(WD.Wavekey),'')
			,  ISNULL(RTRIM(LOC.LocationType),'')
			,  ISNULL(RTRIM(PD.Loc),'')


   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

SET QUOTED_IDENTIFIER OFF 

GO