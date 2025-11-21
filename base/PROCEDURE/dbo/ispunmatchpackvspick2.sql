SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[ispUnmatchPackvsPick2] 
(@c_LoadKey NVARCHAR(10),
 @c_MBOLKey NVARCHAR(10), 
 @c_OnlyShowPickedTote NVARCHAR(1) = 'N')      
AS        
BEGIN
    SET NOCOUNT ON          
    SET QUOTED_IDENTIFIER OFF          
    SET ANSI_NULLS OFF          
    SET CONCAT_NULL_YIELDS_NULL OFF 
    
    -- Calculate Total Packed Qty for Load    
    
    SET @c_LoadKey = ISNULL(RTRIM(@c_LoadKey) ,'')    
    SET @c_MBOLKey = ISNULL(RTRIM(@c_MBOLKey) ,'')    
    
    IF @c_LoadKey=''  AND @c_MBOLKey=''
        RETURN    
    
    IF LEN(@c_LoadKey)>0 AND LEN(@c_MBOLKey)>0
        RETURN    
    
    -- Calculate Total Picked Qty for Load     
    IF OBJECT_ID('tempdb..#pick') IS NOT NULL
        DROP TABLE #pick    
    
    SELECT o.LoadKey
          ,pd.orderkey
          ,o.Storerkey
          ,pd.sku
          ,SUM(PD.Qty) AS qty 
           INTO #pick
    FROM   PickDetail pd(NOLOCK)
    JOIN ORDERS o(NOLOCK) ON  o.OrderKey = pd.OrderKey
    WHERE  (o.LoadKey=@c_LoadKey OR @c_LoadKey='')
    AND    (o.MBOLKey=@c_MBOLKey OR @c_MBOLKey='')
    AND    pd.qty>0
    GROUP BY
           o.LoadKey
          ,pd.orderkey
          ,o.Storerkey
          ,pd.sku

    IF OBJECT_ID('tempdb..#pack') IS NOT NULL
        DROP TABLE #pack    
              
    SELECT o.LoadKey
          ,ph.orderkey
          ,o.Storerkey
          ,pd.sku
          ,SUM(PD.Qty) AS qty 
    INTO #pack
    FROM   PackDetail pd(NOLOCK) 
    JOIN PackHeader ph(NOLOCK) ON  ph.PickSlipNo = pd.PickSlipNo
    JOIN ORDERS o(NOLOCK) ON  o.OrderKey = ph.OrderKey
    WHERE  (o.LoadKey=@c_LoadKey OR @c_LoadKey='')
    AND    (o.MBOLKey=@c_MBOLKey OR @c_MBOLKey='')
    GROUP BY
           o.LoadKey
          ,ph.orderkey
          ,o.Storerkey
          ,pd.sku


    IF OBJECT_ID('tempdb..#result_hd') IS NOT NULL
        DROP TABLE #result_hd    
    
    CREATE TABLE #result_hd 
    (  HD_SeqNo INT IDENTITY(1,1), 
       LoadKey   NVARCHAR(10), 
       OrderKey  NVARCHAR(10),
       StorerKey NVARCHAR(15),
       SKU       NVARCHAR(20),
       PackQty   INT, 
       PickQty   INT
       )
    
    -- List Pick & Pack Not Match -every thing 
    INSERT INTO #result_hd (LoadKey, OrderKey, StorerKey, SKU, PackQty, PickQty)   
    SELECT ISNULL(b.LoadKey ,a.LoadKey) AS LoadKey
          ,ISNULL(b.orderkey ,a.orderkey) AS OrderKey
          ,ISNULL(b.Storerkey ,a.Storerkey) AS StorerKey
          ,ISNULL(b.sku ,a.sku) AS SKU 
          ,ISNULL(a.qty,0) PackQty
          ,ISNULL(b.qty,0) PickQty 
    FROM   #pack A
    FULL OUTER JOIN #pick B ON  A.orderkey = b.orderkey
    AND             a.sku = b.sku
    WHERE  a.qty IS NULL
    OR     b.qty IS NULL
    OR     a.qty<>b.qty
    ORDER BY ISNULL(b.orderkey ,a.orderkey)    
    
    
    IF OBJECT_ID('tempdb..#result_dt') IS NOT NULL
        DROP TABLE #result_dt    

    CREATE TABLE #result_dt
    ( HD_SeqNo       INT, 
      DT_SeqNo       INT IDENTITY(1,1),
      PickMethod     NVARCHAR(10),
      DROPID_PIK     NVARCHAR(18),
      DROPID_PKG     NVARCHAR(18),
      TM_Qty         INT,
      Pick_Qty       INT,
      Pack_Qty       INT,
      Short_Qty      INT )
      
    
    DECLARE @c_OrderKey NVARCHAR(10)
           , @c_SKU     NVARCHAR(20) 
           , @n_PackQty INT
           , @n_PickQty INT
           , @n_ShortQty INT 
            
    DECLARE 
      @n_TM_PPAQty      INT,
      @n_TM_DPKQty      INT, 
      @n_PPAPicked      INT,
      @n_DPKPicked      INT, 
      @n_PPAPacked      INT,
      @n_DPKPacked      INT, 
      @c_DROPID_PIK     NVARCHAR(18),
      @c_DROPID_PKG     NVARCHAR(18), 
      @n_HD_SeqNo       INT,
      @c_StorerKey      NVARCHAR(15) 
        
    DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT HD_SeqNo, OrderKey, StorerKey, SKU, PackQty, PickQty 
    FROM #result_hd 
    
    OPEN  CUR_RESULT 
    
    FETCH NEXT FROM CUR_RESULT INTO @n_HD_SeqNo, @c_OrderKey, @c_StorerKey, @c_SKU, @n_PackQty, @n_PickQty 
    WHILE @@FETCH_STATUS <> -1
    BEGIN
       SET @n_TM_PPAQty = 0
       SET @n_TM_DPKQty = 0 
       SET @n_PPAPicked = 0
       SET @n_DPKPicked = 0 
       SET @n_PPAPacked = 0
       SET @n_DPKPacked = 0 

       DECLARE CUR_PPA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
       SELECT ISNULL(SUM(CASE WHEN PICKDETAIL.[Status] = '0' THEN PICKDETAIL.QTY ELSE 0 END),0), 
              ISNULL(PICKDETAIL.DROPID,''), 
              ISNULL(SUM(CASE WHEN PICKDETAIL.[Status] = '5' THEN PICKDETAIL.QTY ELSE 0 END),0), 
              ISNULL(SUM(CASE WHEN PICKDETAIL.[Status] = '4' THEN PICKDETAIL.QTY ELSE 0 END),0)          
       FROM   PICKDETAIL WITH (NOLOCK) 
       JOIN   LOC WITH (NOLOCK) ON PICKDETAIL.LOC = LOC.LOC  
       WHERE  PICKDETAIL.OrderKey = @c_OrderKey 
       AND    PICKDETAIL.SKU = @c_SKU 
       AND    LOC.LocationType = 'PICK'
       GROUP BY ISNULL(PICKDETAIL.DROPID,'')
                            
       OPEN CUR_PPA 
       FETCH NEXT FROM CUR_PPA INTO @n_TM_PPAQty, @c_DROPID_PIK, @n_PPAPicked, @n_ShortQty
       
       WHILE @@FETCH_STATUS <> -1
       BEGIN
          SET @n_PPAPacked = 0 
          
          SELECT @n_PPAPacked = ISNULL(SUM(QTY),0) 
          FROM   PackDetail pd (NOLOCK)
          JOIN   PackHeader ph (NOLOCK) ON ph.PickSlipNo = pd.PickSlipNo
          WHERE  ph.OrderKey = @c_OrderKey
          AND    pd.SKU = @c_SKU 
          AND    Pd.DropID = @c_DROPID_PIK
          
          IF @n_PPAPacked > 0
            SET @c_DROPID_PKG=@c_DROPID_PIK  
          ELSE 
            SET @c_DROPID_PKG=''
           
          INSERT INTO #result_dt(HD_SeqNo, DROPID_PIK, DROPID_PKG, TM_Qty,
                      Pick_Qty, Pack_Qty, PickMethod, Short_Qty)
          VALUES (@n_HD_SeqNo, @c_DROPID_PIK, @c_DROPID_PKG, @n_TM_PPAQty,
                      @n_PPAPicked, @n_PPAPacked, 'PPA', @n_ShortQty)
          
          FETCH NEXT FROM CUR_PPA INTO @n_TM_PPAQty, @c_DROPID_PIK, @n_PPAPicked, @n_ShortQty
       END
       CLOSE CUR_PPA 
       DEALLOCATE CUR_PPA
       
       
       DECLARE CUR_DPK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
       SELECT ISNULL(SUM(CASE WHEN PICKDETAIL.[Status] = '0' THEN PICKDETAIL.QTY ELSE 0 END),0), 
              ISNULL(PICKDETAIL.CASEID,''), 
              ISNULL(SUM(CASE WHEN PICKDETAIL.[Status] IN ('3','5') THEN PICKDETAIL.QTY ELSE 0 END),0), 
              ISNULL(SUM(CASE WHEN PICKDETAIL.[Status] = '4' THEN PICKDETAIL.QTY ELSE 0 END),0),
              ISNULL(PICKDETAIL.AltSku, ''),
              ISNULL(SUM(CASE WHEN PICKDETAIL.AltSKU <> '' THEN PICKDETAIL.QTY ELSE 0 END),0)         
       FROM   PICKDETAIL WITH (NOLOCK) 
       JOIN   LOC WITH (NOLOCK) ON PICKDETAIL.LOC = LOC.LOC  
       WHERE  PICKDETAIL.OrderKey = @c_OrderKey 
       AND    PICKDETAIL.SKU = @c_SKU 
       AND    LOC.LocationType <> 'PICK'
       GROUP BY ISNULL(PICKDETAIL.CASEID,''), ISNULL(PICKDETAIL.AltSku, '')
                            
       OPEN CUR_DPK 
       FETCH NEXT FROM CUR_DPK INTO @n_TM_DPKQty, @c_DROPID_PIK, @n_DPKPicked, @n_ShortQty, @c_DROPID_PKG, @n_DPKPacked
       
       WHILE @@FETCH_STATUS <> -1
       BEGIN           
          INSERT INTO #result_dt(HD_SeqNo, DROPID_PIK, DROPID_PKG, TM_Qty,
                      Pick_Qty, Pack_Qty, PickMethod, Short_Qty)
          VALUES (@n_HD_SeqNo, @c_DROPID_PIK, @c_DROPID_PKG, @n_TM_DPKQty,
                      @n_DPKPicked, @n_DPKPacked, 'DPK', @n_ShortQty)
        
          FETCH NEXT FROM CUR_DPK INTO @n_TM_DPKQty, @c_DROPID_PIK, @n_DPKPicked, @n_ShortQty, @c_DROPID_PKG, @n_DPKPacked  
       END
       CLOSE CUR_DPK 
       DEALLOCATE CUR_DPK
       
       FETCH NEXT FROM CUR_RESULT INTO @n_HD_SeqNo, @c_OrderKey, @c_StorerKey, @c_SKU, @n_PackQty, @n_PickQty 
    END
    CLOSE CUR_RESULT 
    DEALLOCATE CUR_RESULT
    
    

    IF @c_OnlyShowPickedTote = 'Y' 
    BEGIN
       SELECT HD.LoadKey
             ,@c_MBOLKey AS MBOLKey
             ,HD.OrderKey
             ,HD.StorerKey 
             ,HD.SKU
             ,HD.PackQty
             ,HD.PickQty
             ,DT.DROPID_PIK, DT.DROPID_PKG
             ,DT.TM_Qty, DT.Pick_Qty, DT.Pack_Qty
             ,DT.PickMethod
             ,DT.Short_Qty 
       FROM #result_hd HD WITH (NOLOCK) 
       JOIN #result_dt DT WITH (NOLOCK) ON HD.HD_SeqNo = DT.HD_SeqNo 
       WHERE DT.DROPID_PIK <> ''
          
    END 
    ELSE
    BEGIN
       SELECT HD.LoadKey
             ,@c_MBOLKey AS MBOLKey
             ,HD.OrderKey
             ,HD.StorerKey 
             ,HD.SKU
             ,HD.PackQty
             ,HD.PickQty
             ,DT.DROPID_PIK, DT.DROPID_PKG
             ,DT.TM_Qty, DT.Pick_Qty, DT.Pack_Qty
             ,DT.PickMethod
             ,DT.Short_Qty 
       FROM #result_hd HD WITH (NOLOCK) 
       JOIN #result_dt DT WITH (NOLOCK) ON HD.HD_SeqNo = DT.HD_SeqNo   
              
    END
        
END

GO